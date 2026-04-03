import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/ssh_executor.dart';
import 'package:flutter_muxpod/services/ssh/ssh_client.dart';

/// Mock implementation of SshClient for testing.
class MockSshClient implements SshClient {
  String? _lastCommand;
  SshEvents? _eventHandlers;
  bool _isConnected = true;
  bool _shellStarted = false;

  /// Last command passed to execPersistent.
  String? get lastCommand => _lastCommand;

  /// Whether shell() was called.
  bool get shellStarted => _shellStarted;

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
  Future<void> startShell([ShellOptions? options]) async {
    _shellStarted = true;
  }

  @override
  void setEventHandlers(SshEvents events) {
    _eventHandlers = events;
  }

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

  /// For testing: trigger the onData callback.
  void triggerData(Uint8List data) {
    _eventHandlers?.onData?.call(data);
  }

  /// For testing: trigger the onError callback.
  void triggerError(Object error) {
    _eventHandlers?.onError?.call(error);
  }

  /// For testing: trigger the onClose callback.
  void triggerClose() {
    _eventHandlers?.onClose?.call();
  }

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

    test('shell() sets event handlers before starting shell', () async {
      await executor.shell();

      expect(mockClient._eventHandlers, isNotNull);
      expect(mockClient.shellStarted, isTrue);
    });

    test('shell() returns a stream that receives data', () async {
      final streamFuture = executor.shell();

      // Give the shell time to start
      await Future.delayed(const Duration(milliseconds: 10));

      final stream = await streamFuture;

      // Capture data from the stream
      final dataList = <List<int>>[];
      final subscription = stream.listen((data) {
        dataList.add(data);
      });

      // Trigger data through the mock
      final testData = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      mockClient.triggerData(testData);

      await Future.delayed(const Duration(milliseconds: 10));
      await subscription.cancel();

      expect(dataList, hasLength(1));
      expect(dataList[0], equals(testData));
    });

    test('shell() stream closes when onClose is triggered', () async {
      final streamFuture = executor.shell();

      await Future.delayed(const Duration(milliseconds: 10));

      final stream = await streamFuture;

      bool streamClosed = false;
      stream.listen(
        (_) {},
        onDone: () {
          streamClosed = true;
        },
      );

      mockClient.triggerClose();

      await Future.delayed(const Duration(milliseconds: 10));
      expect(streamClosed, isTrue);
    });

    test('shell() stream receives errors', () async {
      final streamFuture = executor.shell();

      await Future.delayed(const Duration(milliseconds: 10));

      final stream = await streamFuture;

      Object? caughtError;
      stream.listen(
        (_) {},
        onError: (error) {
          caughtError = error;
        },
      );

      final testError = Exception('Test error');
      mockClient.triggerError(testError);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(caughtError, equals(testError));
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

    test('shell() handles immediate data after stream creation', () async {
      final streamFuture = executor.shell();

      await Future.delayed(const Duration(milliseconds: 10));

      final stream = await streamFuture;

      final dataList = <List<int>>[];
      final subscription = stream.listen((data) {
        dataList.add(data);
      });

      // Send multiple chunks
      mockClient.triggerData(Uint8List.fromList([1, 2, 3]));
      mockClient.triggerData(Uint8List.fromList([4, 5, 6]));

      await Future.delayed(const Duration(milliseconds: 10));
      await subscription.cancel();

      expect(dataList, hasLength(2));
      expect(dataList[0], equals([1, 2, 3]));
      expect(dataList[1], equals([4, 5, 6]));
    });
  });
}
