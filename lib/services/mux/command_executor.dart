import 'dart:typed_data';

/// A bidirectional interactive shell session.
class InteractiveShell {
  InteractiveShell({
    required this.stdout,
    required this.write,
    required this.resize,
    required this.close,
  });

  final Stream<List<int>> stdout;
  final void Function(Uint8List data) write;
  final void Function(int cols, int rows) resize;
  final Future<void> Function() close;
}

/// Abstract interface for executing commands on a target system.
///
/// Implementations handle the transport layer (SSH, local, WSL bridge)
/// while callers remain transport-agnostic.
abstract class CommandExecutor {
  /// Execute a command and return its output.
  Future<String> execute(String command);

  /// Open a bidirectional interactive shell session.
  ///
  /// Returns an [InteractiveShell] with stdin/stdout streams, resize support,
  /// and a close callback. The concrete implementation determines the transport:
  /// - [SshExecutor] wraps dartssh2 SSHSession
  /// - [WslBridgeExecutor] delegates to the inner executor
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24});

  /// Release resources held by this executor.
  Future<void> dispose();
}
