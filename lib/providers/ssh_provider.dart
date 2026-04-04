import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/foreground_task_service.dart';
import '../services/network/network_monitor.dart';
import '../services/ssh/ssh_client.dart';
import 'connection_provider.dart';
import 'settings_provider.dart';

/// SSH connection state
class SshState {
  final SshConnectionState connectionState;
  final String? error;
  final String? sessionTitle;
  final bool isReconnecting;
  final int reconnectAttempt;
  final int? reconnectDelayMs;

  /// Whether the network is available
  final bool isNetworkAvailable;

  /// Scheduled time for the next retry
  final DateTime? nextRetryAt;

  /// Whether reconnection is paused (when the network is unavailable)
  final bool isPaused;

  const SshState({
    this.connectionState = SshConnectionState.disconnected,
    this.error,
    this.sessionTitle,
    this.isReconnecting = false,
    this.reconnectAttempt = 0,
    this.reconnectDelayMs,
    this.isNetworkAvailable = true,
    this.nextRetryAt,
    this.isPaused = false,
  });

  SshState copyWith({
    SshConnectionState? connectionState,
    String? error,
    String? sessionTitle,
    bool? isReconnecting,
    int? reconnectAttempt,
    int? reconnectDelayMs,
    bool? isNetworkAvailable,
    DateTime? nextRetryAt,
    bool? isPaused,
  }) {
    return SshState(
      connectionState: connectionState ?? this.connectionState,
      error: error,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      reconnectDelayMs: reconnectDelayMs,
      isNetworkAvailable: isNetworkAvailable ?? this.isNetworkAvailable,
      nextRetryAt: nextRetryAt,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  bool get isConnected => connectionState == SshConnectionState.connected;
  bool get isConnecting => connectionState == SshConnectionState.connecting;
  bool get isDisconnected => connectionState == SshConnectionState.disconnected;
  bool get hasError => connectionState == SshConnectionState.error;

  /// Whether we are waiting offline
  bool get isWaitingForNetwork => isPaused && !isNetworkAvailable;
}

/// Notifier that manages SSH connections
class SshNotifier extends Notifier<SshState> {
  SshClient? _client;
  final SshForegroundTaskService _foregroundService = SshForegroundTaskService();

  // Reconnection cache
  Connection? _lastConnection;
  SshConnectOptions? _lastOptions;

  // Unlimited retry mode (0 = unlimited)
  static const int _maxReconnectAttempts = 0; // unlimited

  // Exponential backoff (max 60 seconds)
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 60000;
  static const double _backoffMultiplier = 1.5;

  // Connection state monitoring
  StreamSubscription<SshConnectionState>? _connectionStateSubscription;

  // Network status monitoring
  StreamSubscription<NetworkStatus>? _networkStatusSubscription;

  // Reconnect timer
  Timer? _reconnectTimer;

  // Disconnect detection callback (configurable from outside)
  void Function()? onDisconnectDetected;

  // Reconnect success callback (configurable from outside)
  void Function()? onReconnectSuccess;

  @override
  SshState build() {
    // Monitor network status
    _startNetworkMonitoring();

    // Register cleanup
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _connectionStateSubscription?.cancel();
      _networkStatusSubscription?.cancel();
      _client?.dispose();
      _foregroundService.stopService();
    });
    return const SshState();
  }

  /// Start monitoring network status
  void _startNetworkMonitoring() {
    final monitor = ref.read(networkMonitorProvider);
    _networkStatusSubscription = monitor.statusStream.listen(_onNetworkStatusChanged);
  }

  /// Handler for network status changes
  void _onNetworkStatusChanged(NetworkStatus status) {
    final isOnline = status == NetworkStatus.online;

    state = state.copyWith(isNetworkAvailable: isOnline);

    if (isOnline) {
      // When recovering from offline to online
      if (state.isPaused && state.isReconnecting) {
        // Try reconnecting immediately (no delay)
        state = state.copyWith(isPaused: false, reconnectAttempt: 0);
        _reconnectTimer?.cancel();
        // Call _doReconnect directly for immediate reconnection
        _doReconnect();
      }
    } else {
      // When going offline
      if (state.isReconnecting) {
        // Pause reconnection
        state = state.copyWith(isPaused: true);
        _reconnectTimer?.cancel();
      }
    }
  }

  /// Calculate reconnection delay (exponential backoff)
  int _calculateDelay(int attempt) {
    final delay = (_baseDelayMs * _pow(_backoffMultiplier, attempt)).round();
    return delay.clamp(_baseDelayMs, _maxDelayMs);
  }

  /// Power calculation
  double _pow(double base, int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  /// Get the SSH client
  SshClient? get client => _client;

  /// Last connection info
  Connection? get lastConnection => _lastConnection;

  /// Last connection options
  SshConnectOptions? get lastOptions => _lastOptions;

  /// Establish an SSH connection with a shell (legacy approach)
  Future<void> connect(Connection connection, SshConnectOptions options) async {
    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
    );

    try {
      _client = SshClient();

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      await _client!.startShell();

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
      );

      // Update the last connection time
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Start the Foreground Service to keep the connection alive in the background
      final askBattery = ref.read(settingsProvider).askBatteryOptimization;
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
        askBatteryOptimization: askBattery,
      );
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// Establish an SSH connection without a shell (for tmux command mode)
  ///
  /// Do not start a shell because only exec() is used.
  Future<void> connectWithoutShell(Connection connection, SshConnectOptions options) async {
    // Cache for reconnection
    _lastConnection = connection;
    _lastOptions = options;

    // Cancel existing connection state monitoring
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    state = state.copyWith(
      connectionState: SshConnectionState.connecting,
      error: null,
      isReconnecting: false,
      reconnectAttempt: 0,
    );

    try {
      _client = SshClient();

      // Listen to the connection state stream (faster disconnect detection)
      _connectionStateSubscription = _client!.connectionStateStream.listen(
        _onConnectionStateChanged,
      );

      await _client!.connect(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        options: options,
      );

      // Do not start a shell (exec only)

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        reconnectAttempt: 0,
      );

      // Update the last connection time
      ref.read(connectionsProvider.notifier).updateLastConnected(connection.id);

      // Start the Foreground Service to keep the connection alive in the background
      final askBattery = ref.read(settingsProvider).askBatteryOptimization;
      await _foregroundService.startService(
        connectionName: connection.name,
        host: connection.host,
        askBatteryOptimization: askBattery,
      );
    } on SshConnectionError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } on SshAuthenticationError catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.message,
      );
      _client?.dispose();
      _client = null;
    } catch (e) {
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: e.toString(),
      );
      _client?.dispose();
      _client = null;
    }
  }

  /// Handler for connection state changes
  ///
  /// Process disconnect detection from keep-alives and sockets immediately.
  void _onConnectionStateChanged(SshConnectionState newState) {
    // When transitioning from connected to disconnected/error
    if (state.isConnected &&
        (newState == SshConnectionState.error ||
         newState == SshConnectionState.disconnected)) {
      // Update the state
      state = state.copyWith(
        connectionState: newState,
        error: newState == SshConnectionState.error ? 'Connection lost' : null,
      );

      // Call the disconnect detection callback
      onDisconnectDetected?.call();

      // Try automatic reconnection if not already reconnecting
      if (!state.isReconnecting) {
        reconnect();
      }
    }
  }

  /// Attempt reconnection
  ///
  /// For automatic reconnection. Tries indefinitely with exponential backoff.
  /// Pauses when offline and resumes automatically on recovery.
  Future<bool> reconnect() async {
    if (_lastConnection == null || _lastOptions == null) {
      return false;
    }

    // Pause when the network is offline
    if (!state.isNetworkAvailable) {
      state = state.copyWith(
        isReconnecting: true,
        isPaused: true,
        error: 'Waiting for network...',
      );
      return false;
    }

    final attempt = state.reconnectAttempt;

    // Check the limit only when retries are not unlimited
    if (_maxReconnectAttempts > 0 && attempt >= _maxReconnectAttempts) {
      state = state.copyWith(
        isReconnecting: false,
        error: 'Max reconnect attempts reached',
      );
      return false;
    }

    final delayMs = _calculateDelay(attempt);
    final nextRetry = DateTime.now().add(Duration(milliseconds: delayMs));

    state = state.copyWith(
      isReconnecting: true,
      isPaused: false,
      reconnectAttempt: attempt + 1,
      reconnectDelayMs: delayMs,
      nextRetryAt: nextRetry,
    );

    // Reconnect after the delay
    final completer = Completer<bool>();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      final result = await _doReconnect();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    return completer.future;
  }

  /// Actual reconnection logic
  Future<bool> _doReconnect() async {
    if (_lastConnection == null || _lastOptions == null) {
      return false;
    }

    // Abort if the network is offline
    if (!state.isNetworkAvailable) {
      state = state.copyWith(isPaused: true);
      return false;
    }

    try {
      // Cancel existing connection state monitoring
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      // Clean up the old client
      _client?.dispose();
      _client = SshClient();

      // Listen to the connection state stream (faster disconnect detection)
      _connectionStateSubscription = _client!.connectionStateStream.listen(
        _onConnectionStateChanged,
      );

      await _client!.connect(
        host: _lastConnection!.host,
        port: _lastConnection!.port,
        username: _lastConnection!.username,
        options: _lastOptions!,
      );

      state = state.copyWith(
        connectionState: SshConnectionState.connected,
        isReconnecting: false,
        isPaused: false,
        reconnectAttempt: 0,
        error: null,
        nextRetryAt: null,
      );

      // Reconnect success callback
      onReconnectSuccess?.call();

      return true;
    } catch (e) {
      // Reconnect failed, schedule the next attempt
      state = state.copyWith(
        connectionState: SshConnectionState.error,
        error: 'Reconnect failed: $e',
      );

      // Automatically schedule the next attempt (for unlimited retries)
      if (_maxReconnectAttempts == 0 || state.reconnectAttempt < _maxReconnectAttempts) {
        // Schedule the next reconnection asynchronously
        Future.microtask(() => reconnect());
      }

      return false;
    }
  }

  /// Try reconnecting immediately (for user action)
  Future<bool> reconnectNow() async {
    _reconnectTimer?.cancel();
    state = state.copyWith(
      reconnectAttempt: 0,
      isPaused: false,
    );
    return _doReconnect();
  }

  /// Check whether the connection is active
  bool checkConnection() {
    return _client != null && _client!.isConnected;
  }

  /// Reset reconnection state
  void resetReconnect() {
    _reconnectTimer?.cancel();
    state = state.copyWith(
      isReconnecting: false,
      isPaused: false,
      reconnectAttempt: 0,
      reconnectDelayMs: null,
      nextRetryAt: null,
    );
  }

  /// Disconnect
  Future<void> disconnect() async {
    // Cancel the reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Cancel connection state monitoring
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Stop the Foreground Service
    await _foregroundService.stopService();

    await _client?.disconnect();
    _client = null;
    state = state.copyWith(
      connectionState: SshConnectionState.disconnected,
      error: null,
      sessionTitle: null,
      isReconnecting: false,
      isPaused: false,
      reconnectAttempt: 0,
      nextRetryAt: null,
    );
  }

  /// Update the session title
  void updateSessionTitle(String title) {
    state = state.copyWith(sessionTitle: title);
  }

  /// Send data
  void write(String data) {
    _client?.write(data);
  }

  /// Resize the terminal
  void resize(int cols, int rows) {
    _client?.resize(cols, rows);
  }
}

/// SSH provider
final sshProvider = NotifierProvider<SshNotifier, SshState>(() {
  return SshNotifier();
});
