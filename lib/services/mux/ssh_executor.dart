import 'dart:typed_data';

import '../ssh/ssh_client.dart';
import 'command_executor.dart';

/// Implementation of [CommandExecutor] that wraps an [SshClient].
///
/// This executor provides command execution and interactive shell capabilities
/// over an SSH connection, delegating to the underlying [SshClient].
class SshExecutor implements CommandExecutor {
  final SshClient _sshClient;

  /// Creates a new SshExecutor wrapping the given [SshClient].
  SshExecutor(this._sshClient);

  @override
  Future<String> execute(String command) async {
    return _sshClient.execPersistent(command);
  }

  @override
  Future<InteractiveShell> openInteractiveShell({
    int cols = 80,
    int rows = 24,
  }) async {
    final session = await _sshClient.openPtyShell(
      cols: cols,
      rows: rows,
    );

    return InteractiveShell(
      stdout: session.stdout,
      write: (Uint8List data) => session.write(data),
      resize: (int cols, int rows) => session.resizeTerminal(cols, rows),
      close: () async => session.close(),
    );
  }

  @override
  Future<void> dispose() async {
    await _sshClient.disconnect();
  }
}
