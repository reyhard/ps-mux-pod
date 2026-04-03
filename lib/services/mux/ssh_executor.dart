import 'dart:async';

import '../ssh/ssh_client.dart';
import 'command_executor.dart';

/// Implementation of CommandExecutor that wraps an SshClient.
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
  Future<Stream<List<int>>> shell() async {
    final controller = StreamController<List<int>>();

    // Set up event handlers to forward data to the stream
    _sshClient.setEventHandlers(
      SshEvents(
        onData: (data) {
          if (!controller.isClosed) {
            controller.add(data);
          }
        },
        onError: (error) {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        },
        onClose: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      ),
    );

    // Start the interactive shell
    try {
      await _sshClient.startShell();
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
      rethrow;
    }

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _sshClient.disconnect();
  }
}
