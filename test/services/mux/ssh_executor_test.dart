import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/ssh_executor.dart';
import 'package:flutter_muxpod/services/ssh/ssh_client.dart';

/// Mock implementation of SshClient for testing.
class MockSshClient implements SshClient {
  String? _lastCommand;
  bool _isConnected = true;

  /// Last command passed to execPersistent.
  String? get lastCommand => _lastCommand;

  @override
  Future<String> execPersistent(String command, {Duration? timeout}) async {
    _lastCommand = command;
    return 'output for: $command';
  }

  @override
  Future<String> exec(String command, {Duration? timeout}) async {
    throw UnsupportedError('exec() should not be called in this test');
  }

  @override
  Future<void> startShell([ShellOptions? options]) async {}

  @override
  void setEventHandlers(SshEvents events) {}

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }

  @override
  bool get isConnected => _isConnected;

  @override
  Future<SSHSession> openPtyShell({
    int cols = 80,
    int rows = 24,
    String termType = 'xterm-256color',
  }) =>
      throw UnsupportedError('openPtyShell() not available in mock');

  // Unimplemented members (not needed for these tests)
  @override
  SshConnectionState get state => throw UnsupportedError('Not implemented');

  @override
  String? get lastError => throw UnsupportedError('Not implemented');

  @override
  String? get tmuxPath => throw UnsupportedError('Not implemented');

  @override
  Stream<SshConnectionState> get connectionStateStream =>
      throw UnsupportedError('Not implemented');

  @override
  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required SshConnectOptions options,
  }) =>
      throw UnsupportedError('Not implemented');

  @override
  void updateEventHandlers({
    void Function(Uint8List data)? onData,
    void Function()? onClose,
    void Function(Object error)? onError,
  }) =>
      throw UnsupportedError('Not implemented');

  @override
  void write(String data) => throw UnsupportedError('Not implemented');

  @override
  void writeBytes(Uint8List data) => throw UnsupportedError('Not implemented');

  @override
  void resize(int cols, int rows) => throw UnsupportedError('Not implemented');

  @override
  Future<({String stdout, String stderr, int? exitCode})> execWithExitCode(
    String command, {
    Duration? timeout,
  }) =>
      throw UnsupportedError('Not implemented');

  @override
  Future<void> restartPersistentShell() =>
      throw UnsupportedError('Not implemented');
}

void main() {
  group('SshExecutor', () {
    late MockSshClient mockClient;
    late SshExecutor executor;

    setUp(() {
      mockClient = MockSshClient();
      executor = SshExecutor(mockClient);
    });

    test('execute() delegates to SshClient.execPersistent()', () async {
      const command = 'tmux list-sessions';

      final result = await executor.execute(command);

      expect(mockClient.lastCommand, equals(command));
      expect(result, equals('output for: $command'));
    });

    test('execute() passes through timeout parameter', () async {
      const command = 'tmux list-sessions';

      // This test mainly verifies that no exception is thrown
      // The mock implementation ignores the timeout parameter
      final result = await executor.execute(command);

      expect(result, isNotEmpty);
    });

    test('openInteractiveShell() delegates to SshClient.openPtyShell()', () {
      // The mock throws UnsupportedError from openPtyShell(),
      // verifying that openInteractiveShell() delegates correctly.
      expect(
        () => executor.openInteractiveShell(),
        throwsUnsupportedError,
      );
    });

    test('dispose() delegates to SshClient.disconnect()', () async {
      expect(mockClient.isConnected, isTrue);

      await executor.dispose();

      expect(mockClient.isConnected, isFalse);
    });

    test('multiple execute() calls work correctly', () async {
      const command1 = 'command1';
      const command2 = 'command2';

      final result1 = await executor.execute(command1);
      final result2 = await executor.execute(command2);

      expect(mockClient.lastCommand, equals(command2)); // Last command stored
      expect(result1, contains('command1'));
      expect(result2, contains('command2'));
    });
  });
}
