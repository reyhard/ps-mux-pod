import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'persistent_shell.dart';

/// SSH connection error
class SshConnectionError implements Exception {
  final String message;
  final Object? cause;

  SshConnectionError(this.message, [this.cause]);

  @override
  String toString() => 'SshConnectionError: $message${cause != null ? ' ($cause)' : ''}';
}

/// SSH authentication error
class SshAuthenticationError implements Exception {
  final String message;
  final Object? cause;

  SshAuthenticationError(this.message, [this.cause]);

  @override
  String toString() => 'SshAuthenticationError: $message${cause != null ? ' ($cause)' : ''}';
}

/// SSH connection options
class SshConnectOptions {
  /// Password used for password authentication
  final String? password;

  /// Private key for key-based authentication (PEM format)
  final String? privateKey;

  /// Private key passphrase
  final String? passphrase;

  /// User-specified tmux path (auto-detected when null)
  final String? tmuxPath;

  /// Connection timeout (seconds)
  final int timeout;

  const SshConnectOptions({
    this.password,
    this.privateKey,
    this.passphrase,
    this.tmuxPath,
    this.timeout = 30,
  });
}

/// Shell options
class ShellOptions {
  /// Terminal type
  final String term;

  /// Number of columns
  final int cols;

  /// Number of rows
  final int rows;

  const ShellOptions({
    this.term = 'xterm-256color',
    this.cols = 80,
    this.rows = 24,
  });
}

/// SSH connection events
class SshEvents {
  /// When data is received
  final void Function(Uint8List data)? onData;

  /// When the connection closes
  final void Function()? onClose;

  /// When an error occurs
  final void Function(Object error)? onError;

  const SshEvents({
    this.onData,
    this.onClose,
    this.onError,
  });

  SshEvents copyWith({
    void Function(Uint8List data)? onData,
    void Function()? onClose,
    void Function(Object error)? onError,
  }) {
    return SshEvents(
      onData: onData ?? this.onData,
      onClose: onClose ?? this.onClose,
      onError: onError ?? this.onError,
    );
  }
}

/// SSH connection state
enum SshConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// SSH client
///
/// Wraps `dartssh2` and manages SSH connections.
class SshClient {
  SSHClient? _client;
  SSHSession? _session;
  SSHSocket? _socket;

  SshConnectionState _state = SshConnectionState.disconnected;
  SshEvents _events = const SshEvents();
  String? _lastError;

  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;

  /// Persistent shell session (for polling)
  PersistentShell? _persistentShell;

  /// Absolute path to the detected tmux binary
  String? _tmuxPath;

  /// Precompiled regex for tmux command substitution
  static final _tmuxCommandRegex = RegExp(r'(^|;\s*)tmux\b');

  /// Lock for exclusive `exec` channel access
  Completer<void>? _execLock;

  /// Absolute path to tmux (null if not detected)
  String? get tmuxPath => _tmuxPath;

  /// Keep-alive timer
  Timer? _keepAliveTimer;

  /// StreamController for connection monitoring
  final _connectionStateController = StreamController<SshConnectionState>.broadcast();

  /// Connection state stream (for external observers)
  Stream<SshConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Minimum keep-alive interval (seconds)
  static const int _minKeepAliveIntervalSeconds = 5;

  /// Maximum keep-alive interval (seconds)
  static const int _maxKeepAliveIntervalSeconds = 30;

  /// Keep-alive timeout (seconds) - shortened to 3 seconds for faster detection
  static const int _keepAliveTimeoutSeconds = 3;

  /// Current keep-alive interval (adjusted dynamically)
  int _currentKeepAliveIntervalSeconds = 10;

  /// Number of consecutive keep-alive successes
  int _keepAliveSuccessCount = 0;

  /// Current connection state
  SshConnectionState get state => _state;

  /// Whether connected
  bool get isConnected => _state == SshConnectionState.connected;

  /// Last error message
  String? get lastError => _lastError;

  /// Establish an SSH connection
  ///
  /// [host] Hostname or IP address
  /// [port] Port number
  /// [username] Username
  /// [options] Connection options (authentication details, etc.)
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required SshConnectOptions options,
  }) async {
    // Validation
    _validateConnectionParams(host, port, username, options);

    _state = SshConnectionState.connecting;
    _lastError = null;

    try {
      // Socket connection
      _socket = await SSHSocket.connect(
        host,
        port,
        timeout: Duration(seconds: options.timeout),
      );

      // Create the client based on the authentication method
      if (options.privateKey != null) {
        // Key-based authentication
        _client = SSHClient(
          _socket!,
          username: username,
          identities: _parsePrivateKey(options.privateKey!, options.passphrase),
          onAuthenticated: _onAuthenticated,
        );
      } else if (options.password != null) {
        // Password authentication
        _client = SSHClient(
          _socket!,
          username: username,
          onPasswordRequest: () => options.password!,
          onAuthenticated: _onAuthenticated,
        );
      } else {
        throw SshAuthenticationError('No authentication method provided');
      }

      // Wait for authentication to complete
      await _client!.authenticated;

      _state = SshConnectionState.connected;
      _connectionStateController.add(_state);

      // Detect the tmux path (use the user-specified path if provided, otherwise auto-detect)
      if (options.tmuxPath != null && options.tmuxPath!.isNotEmpty) {
        // Verify that the user-specified path exists
        final verifyExitCode = await _withExecLock(() async {
          final session = await _client!.execute('test -x ${options.tmuxPath}');
          await session.stdout.drain();
          await session.stderr.drain();
          final code = session.exitCode;
          session.close();
          return code;
        });
        if (verifyExitCode == 0) {
          _tmuxPath = options.tmuxPath;
          debugPrint('connect: user-specified tmux path verified: $_tmuxPath');
        } else {
          debugPrint('connect: user-specified tmux path not found: ${options.tmuxPath}');
        }
      } else {
        await _detectTmuxPath();
      }

      // Start the persistent shell (for polling)
      await _startPersistentShell();

      // Start keep-alives
      _startKeepAlive();
    } on SocketException catch (e) {
      _state = SshConnectionState.error;
      _lastError = 'Connection failed: ${e.message}';
      await _cleanup();
      throw SshConnectionError(_lastError!, e);
    } on SSHAuthFailError catch (e) {
      _state = SshConnectionState.error;
      _lastError = 'Authentication failed: ${e.message}';
      await _cleanup();
      throw SshAuthenticationError(_lastError!, e);
    } catch (e) {
      _state = SshConnectionState.error;
      _lastError = 'Connection failed: $e';
      await _cleanup();
      throw SshConnectionError(_lastError!, e);
    }
  }

  /// Validate connection parameters
  void _validateConnectionParams(
    String host,
    int port,
    String username,
    SshConnectOptions options,
  ) {
    if (host.trim().isEmpty) {
      throw SshConnectionError('Host is required');
    }
    if (username.trim().isEmpty) {
      throw SshConnectionError('Username is required');
    }
    if (port < 1 || port > 65535) {
      throw SshConnectionError('Invalid port number: $port');
    }
    if (options.password == null && options.privateKey == null) {
      throw SshAuthenticationError(
        'Either password or privateKey must be provided',
      );
    }
  }

  /// Parse a private key
  List<SSHKeyPair> _parsePrivateKey(String privateKey, String? passphrase) {
    try {
      // SSHKeyPair.fromPem returns a List<SSHKeyPair>
      final keyPairs = SSHKeyPair.fromPem(privateKey, passphrase);
      if (keyPairs.isEmpty) {
        throw SshAuthenticationError('No valid key found in PEM data');
      }
      return keyPairs;
    } on FormatException catch (e) {
      throw SshAuthenticationError('Invalid private key format: ${e.message}');
    } catch (e) {
      if (e is SshAuthenticationError) rethrow;
      if (passphrase == null && privateKey.contains('ENCRYPTED')) {
        throw SshAuthenticationError('Private key is encrypted, passphrase required');
      }
      throw SshAuthenticationError('Failed to parse private key: $e');
    }
  }

  /// Authentication completion callback
  void _onAuthenticated() {
    // Authentication succeeded
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _cleanup();
    _updateState(SshConnectionState.disconnected);
    _events.onClose?.call();
  }

  /// Update state and notify the stream
  void _updateState(SshConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionStateController.add(newState);
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    // Stop keep-alives
    _stopKeepAlive();

    // Dispose the persistent shell
    await _persistentShell?.dispose();
    _persistentShell = null;

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    _session?.close();
    _session = null;

    _client?.close();
    _client = null;

    _socket?.close();
    _socket = null;
  }

  /// Start the persistent shell
  Future<void> _startPersistentShell() async {
    if (_client == null) return;

    try {
      _persistentShell = PersistentShell(_client!);
      await _persistentShell!.start();
    } catch (e) {
      // Even if the persistent shell fails to start, keep the connection alive
      // Fall back to the legacy exec() method
      _persistentShell = null;
    }
  }

  /// Restart the persistent shell
  Future<void> restartPersistentShell() async {
    if (_client == null || !isConnected) return;

    try {
      await _persistentShell?.dispose();
      _persistentShell = PersistentShell(_client!);
      await _persistentShell!.start();
    } catch (e) {
      _persistentShell = null;
    }
  }

  /// Use the exec channel exclusively
  Future<T> _withExecLock<T>(Future<T> Function() fn) async {
    while (_execLock != null) {
      await _execLock!.future;
    }
    final completer = Completer<void>();
    _execLock = completer;
    try {
      return await fn();
    } finally {
      _execLock = null;
      completer.complete();
    }
  }

  /// Detect the absolute tmux path via the exec channel
  ///
  /// Step 1: Run `command -v tmux` via a login shell
  /// Step 2: If that fails, fall back to `test -x` against known candidate paths
  Future<void> _detectTmuxPath() async {
    if (_client == null || !isConnected) return;

    // Step 1: detect via login shell
    try {
      final path = await _withExecLock(() async {
        final session = await _client!.execute(
          r"$SHELL -lc 'command -v tmux'",
        );
        final stdoutBytes = <int>[];
        await session.stdout.forEach((data) => stdoutBytes.addAll(data));
        await session.stderr.drain();
        session.close();
        return utf8.decode(stdoutBytes, allowMalformed: true).trim();
      });
      if (path.isNotEmpty && path.startsWith('/')) {
        _tmuxPath = path;
        debugPrint('_detectTmuxPath: found via login shell: $path');
        return;
      }
    } catch (e) {
      debugPrint('_detectTmuxPath: login shell detection failed: $e');
    }

    // Step 2: fallback to known paths
    const candidates = [
      '/opt/homebrew/bin/tmux',
      '/usr/local/bin/tmux',
      '/usr/bin/tmux',
    ];

    for (final candidate in candidates) {
      try {
        final exitCode = await _withExecLock(() async {
          final session = await _client!.execute('test -x $candidate');
          await session.stdout.drain();
          await session.stderr.drain();
          final code = session.exitCode;
          session.close();
          return code;
        });
        if (exitCode == 0) {
          _tmuxPath = candidate;
          debugPrint('_detectTmuxPath: found via fallback: $candidate');
          return;
        }
      } catch (e) {
        debugPrint('_detectTmuxPath: error checking $candidate: $e');
      }
    }
    debugPrint('_detectTmuxPath: tmux not found');
  }

  /// Replace `tmux` in a command with the detected absolute path
  String _resolveTmuxCommand(String command) {
    if (_tmuxPath == null) return command;
    return command.replaceAllMapped(
      _tmuxCommandRegex,
      (m) => '${m[1]}$_tmuxPath',
    );
  }

  /// Start keep-alives
  ///
  /// Periodically run a lightweight command to verify the connection is alive.
  /// If the connection is lost, transition to an error state immediately.
  /// The interval is adjusted dynamically (longer on success, shorter on failure).
  void _startKeepAlive() {
    _stopKeepAlive();
    _currentKeepAliveIntervalSeconds = 10; // initial value: 10 seconds
    _keepAliveSuccessCount = 0;
    _scheduleNextKeepAlive();
  }

  /// Schedule the next keep-alive
  void _scheduleNextKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(
      Duration(seconds: _currentKeepAliveIntervalSeconds),
      () async {
        await _sendKeepAlive();
        if (isConnected) {
          _scheduleNextKeepAlive();
        }
      },
    );
  }

  /// Stop keep-alives
  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Adjust the keep-alive interval
  void _adjustKeepAliveInterval({required bool success}) {
    if (success) {
      _keepAliveSuccessCount++;
      // Extend the interval after 3 consecutive successes
      if (_keepAliveSuccessCount >= 3) {
        _currentKeepAliveIntervalSeconds = (_currentKeepAliveIntervalSeconds + 5)
            .clamp(_minKeepAliveIntervalSeconds, _maxKeepAliveIntervalSeconds);
        _keepAliveSuccessCount = 0;
      }
    } else {
      // Reset to the minimum interval on failure
      _currentKeepAliveIntervalSeconds = _minKeepAliveIntervalSeconds;
      _keepAliveSuccessCount = 0;
    }
  }

  /// Send a keep-alive packet
  Future<void> _sendKeepAlive() async {
    if (!isConnected || _client == null) {
      return;
    }

    try {
      // Use the persistent shell for keep-alives (fast)
      await execPersistent(
        'echo ping',
        timeout: Duration(seconds: _keepAliveTimeoutSeconds),
      );
      _adjustKeepAliveInterval(success: true);
    } catch (e) {
      _adjustKeepAliveInterval(success: false);
      // Keep-alive failure = connection lost
      _lastError = 'Connection lost: $e';
      _updateState(SshConnectionState.error);
      _events.onError?.call(SshConnectionError(_lastError!));
      _events.onClose?.call();
    }
  }

  /// Opens a new PTY shell session for interactive terminal use.
  ///
  /// Unlike [startShell] (which manages the single [_session] field),
  /// this creates an independent shell that the caller manages.
  /// Used by [SshExecutor] to provide PTY streams for terminal attachment.
  Future<SSHSession> openPtyShell({
    int cols = 80,
    int rows = 24,
    String termType = 'xterm-256color',
  }) async {
    if (_client == null || !isConnected) {
      throw SshConnectionError('Not connected');
    }
    final session = await _client!.shell(
      pty: SSHPtyConfig(
        type: termType,
        width: cols,
        height: rows,
      ),
    );
    return session;
  }

  /// Start an interactive shell
  ///
  /// [options] Shell options
  Future<void> startShell([ShellOptions options = const ShellOptions()]) async {
    if (!isConnected || _client == null) {
      throw SshConnectionError('Not connected');
    }

    try {
      _session = await _client!.shell(
        pty: SSHPtyConfig(
          type: options.term,
          width: options.cols,
          height: options.rows,
        ),
      );

      // Set up stdout/stderr listeners
      _stdoutSubscription = _session!.stdout.listen(
        _handleData,
        onError: _handleError,
        onDone: _handleDone,
      );

      _stderrSubscription = _session!.stderr.listen(
        _handleData,
        onError: _handleError,
      );
    } catch (e) {
      throw SshConnectionError('Failed to start shell: $e', e);
    }
  }

  /// Data receive handler
  void _handleData(Uint8List data) {
    _events.onData?.call(data);
  }

  /// Error handler
  void _handleError(Object error) {
    _lastError = error.toString();
    _events.onError?.call(error);
  }

  /// Completion handler
  void _handleDone() {
    _state = SshConnectionState.disconnected;
    _events.onClose?.call();
  }

  /// Write data to the shell
  ///
  /// [data] Data to send (string)
  void write(String data) {
    if (!isConnected || _session == null) {
      throw SshConnectionError('Not connected or shell not started');
    }
    _session!.write(utf8.encode(data));
  }

  /// Write byte data to the shell
  ///
  /// [data] Data to send (bytes)
  void writeBytes(Uint8List data) {
    if (!isConnected || _session == null) {
      throw SshConnectionError('Not connected or shell not started');
    }
    _session!.write(data);
  }

  /// Resize the terminal
  ///
  /// [cols] Number of columns
  /// [rows] Number of rows
  void resize(int cols, int rows) {
    if (_session == null) {
      return; // do nothing if the shell has not started
    }

    try {
      _session!.resizeTerminal(cols, rows);
    } catch (e) {
      // Resize errors are warnings only (not fatal)
      _lastError = 'Failed to resize: $e';
    }
  }

  /// Execute a command and return the result
  ///
  /// [command] Command to execute
  /// [timeout] Timeout duration
  /// Returns: command output
  Future<String> exec(String command, {Duration? timeout}) async {
    if (!isConnected || _client == null) {
      throw SshConnectionError('Not connected');
    }

    try {
      final resolvedCommand = _resolveTmuxCommand(command);
      return await _withExecLock(() async {
        final session = await _client!.execute(resolvedCommand);

        // Collect output as bytes and decode at the end
        final stdoutBytes = <int>[];
        final stderrBytes = <int>[];

        final stdoutCompleter = Completer<void>();
        final stderrCompleter = Completer<void>();

        session.stdout.listen(
          (data) => stdoutBytes.addAll(data),
          onDone: () => stdoutCompleter.complete(),
          onError: (e) => stdoutCompleter.completeError(e),
        );

        session.stderr.listen(
          (data) => stderrBytes.addAll(data),
          onDone: () => stderrCompleter.complete(),
          onError: (e) => stderrCompleter.completeError(e),
        );

        // Wait for completion with a timeout
        if (timeout != null) {
          await Future.wait([
            stdoutCompleter.future,
            stderrCompleter.future,
          ]).timeout(timeout);
        } else {
          await Future.wait([
            stdoutCompleter.future,
            stderrCompleter.future,
          ]);
        }

        session.close();

        // Decode bytes as UTF-8 (invalid bytes are replaced)
        final stdout = utf8.decode(stdoutBytes, allowMalformed: true);
        final stderr = utf8.decode(stderrBytes, allowMalformed: true);

        // Treat stderr as an error when present (optional)
        if (stderr.isNotEmpty) {
          // Include stderr in the result as well (some commands such as tmux may write there)
          debugPrint('exec: stdout="${stdout.trim()}", stderr="${stderr.trim()}"');
          return stdout + stderr;
        }

        debugPrint('exec: stdout="${stdout.trim()}"');
        return stdout;
      });
    } on TimeoutException {
      debugPrint('exec: timed out');
      throw SshConnectionError('Command execution timed out');
    } catch (e) {
      debugPrint('exec: error=$e');
      throw SshConnectionError('Failed to execute command: $e', e);
    }
  }

  /// Execute a command through the persistent shell (fast)
  ///
  /// Eliminates channel open/close overhead and can run in about one RTT.
  /// Suitable for frequent command execution such as polling.
  ///
  /// [command] Command to execute
  /// [timeout] Timeout duration
  /// Returns: command output
  Future<String> execPersistent(String command, {Duration? timeout}) async {
    if (!isConnected || _client == null) {
      throw SshConnectionError('Not connected');
    }

    final resolvedCommand = _resolveTmuxCommand(command);

    // Fall back to the legacy exec() if the persistent shell is unavailable
    if (_persistentShell == null || !_persistentShell!.isStarted) {
      return exec(resolvedCommand, timeout: timeout);
    }

    try {
      return await _persistentShell!.exec(resolvedCommand, timeout: timeout);
    } on PersistentShellError catch (e) {
      // Try to restart if the shell session has disconnected
      if (e.message.contains('closed') || e.message.contains('disposed')) {
        try {
          await restartPersistentShell();
          return await _persistentShell!.exec(resolvedCommand, timeout: timeout);
        } catch (_) {
          // Fall back to the legacy exec() if restart also fails
          return exec(resolvedCommand, timeout: timeout);
        }
      }
      // Fall back to the legacy exec() for other errors
      return exec(resolvedCommand, timeout: timeout);
    }
  }

  /// Execute a command and return the exit code
  ///
  /// [command] Command to execute
  /// Returns: (stdout, stderr, exitCode)
  Future<({String stdout, String stderr, int? exitCode})> execWithExitCode(
    String command, {
    Duration? timeout,
  }) async {
    if (!isConnected || _client == null) {
      throw SshConnectionError('Not connected');
    }

    try {
      final resolvedCommand = _resolveTmuxCommand(command);
      return await _withExecLock(() async {
        final session = await _client!.execute(resolvedCommand);

        // Accumulate bytes to prevent UTF-8 boundary splits caused by chunk-level decoding
        final stdoutBytes = <int>[];
        final stderrBytes = <int>[];

        final stdoutCompleter = Completer<void>();
        final stderrCompleter = Completer<void>();

        session.stdout.listen(
          (data) => stdoutBytes.addAll(data),
          onDone: () => stdoutCompleter.complete(),
          onError: (e) => stdoutCompleter.completeError(e),
        );

        session.stderr.listen(
          (data) => stderrBytes.addAll(data),
          onDone: () => stderrCompleter.complete(),
          onError: (e) => stderrCompleter.completeError(e),
        );

        if (timeout != null) {
          await Future.wait([
            stdoutCompleter.future,
            stderrCompleter.future,
          ]).timeout(timeout);
        } else {
          await Future.wait([
            stdoutCompleter.future,
            stderrCompleter.future,
          ]);
        }

        final exitCode = session.exitCode;
        session.close();

        return (
          stdout: utf8.decode(stdoutBytes, allowMalformed: true),
          stderr: utf8.decode(stderrBytes, allowMalformed: true),
          exitCode: exitCode,
        );
      });
    } on TimeoutException {
      throw SshConnectionError('Command execution timed out');
    } catch (e) {
      throw SshConnectionError('Failed to execute command: $e', e);
    }
  }

  /// Set event handlers
  void setEventHandlers(SshEvents events) {
    _events = events;
  }

  /// Update event handlers
  void updateEventHandlers({
    void Function(Uint8List data)? onData,
    void Function()? onClose,
    void Function(Object error)? onError,
  }) {
    _events = _events.copyWith(
      onData: onData,
      onClose: onClose,
      onError: onError,
    );
  }

  /// Release resources
  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
  }
}

/// Create an SSH client
SshClient createSshClient() {
  return SshClient();
}
