import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/command_executor.dart';
import 'package:flutter_muxpod/services/mux/wsl_executor.dart';

// ---------------------------------------------------------------------------
// Manual mock
// ---------------------------------------------------------------------------

class _MockCommandExecutor implements CommandExecutor {
  final List<String> executedCommands = [];
  bool disposeCalled = false;

  @override
  Future<String> execute(String command) async {
    executedCommands.add(command);
    return 'mock output';
  }

  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    throw UnimplementedError('Not needed for WSL executor tests');
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WslBridgeExecutor', () {
    late _MockCommandExecutor inner;

    setUp(() {
      inner = _MockCommandExecutor();
    });

    group('execute()', () {
      test('prefixes command with "wsl -d Ubuntu --"', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        await executor.execute('ls -la');

        expect(inner.executedCommands, hasLength(1));
        expect(inner.executedCommands.first, equals('wsl -d Ubuntu -- ls -la'));
      });

      test('uses the configured distro name in the prefix', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Debian');

        await executor.execute('uname -a');

        expect(inner.executedCommands.first, equals('wsl -d Debian -- uname -a'));
      });

      test('passes different distro names correctly', () async {
        final executorA = WslBridgeExecutor(inner, distro: 'Ubuntu-22.04');
        final executorB = WslBridgeExecutor(inner, distro: 'openSUSE-Leap-15.5');

        await executorA.execute('echo hello');
        await executorB.execute('echo world');

        expect(inner.executedCommands[0], equals('wsl -d Ubuntu-22.04 -- echo hello'));
        expect(inner.executedCommands[1], equals('wsl -d openSUSE-Leap-15.5 -- echo world'));
      });

      test('returns the inner executor result', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        final result = await executor.execute('pwd');

        expect(result, equals('mock output'));
      });

      test('passes commands with spaces and flags unchanged after --', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        await executor.execute('tmux list-sessions -F "#{session_name}"');

        expect(
          inner.executedCommands.first,
          equals('wsl -d Ubuntu -- tmux list-sessions -F "#{session_name}"'),
        );
      });
    });

    group('openInteractiveShell()', () {
      test('delegates to inner executor openInteractiveShell()', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        // Inner mock throws UnimplementedError, so we expect the same.
        expect(
          () => executor.openInteractiveShell(),
          throwsUnimplementedError,
        );
      });
    });

    group('dispose()', () {
      test('does NOT dispose the inner executor', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        await executor.dispose();

        expect(inner.disposeCalled, isFalse,
            reason: 'WslBridgeExecutor must not dispose its inner executor; '
                'the caller is responsible for the inner executor lifecycle.');
      });

      test('dispose() completes without error', () async {
        final executor = WslBridgeExecutor(inner, distro: 'Ubuntu');

        // Should complete normally.
        await expectLater(executor.dispose(), completes);
      });
    });
  });
}
