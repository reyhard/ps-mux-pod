/// Abstract interface for executing commands on a target system.
///
/// Implementations handle the transport layer (SSH, local, WSL bridge)
/// while callers remain transport-agnostic.
abstract class CommandExecutor {
  /// Execute a command and return its output.
  Future<String> execute(String command);

  /// Open an interactive terminal byte stream.
  ///
  /// Returns a stream of raw bytes for interactive terminal I/O.
  /// The concrete implementation determines the transport:
  /// - [SshExecutor] wraps dartssh2 SSHSession
  /// - [WslBridgeExecutor] wraps a Process stdin/stdout
  Future<Stream<List<int>>> shell();

  /// Release resources held by this executor.
  Future<void> dispose();
}
