import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/command_executor.dart';
import 'package:flutter_muxpod/services/mux/mux_models.dart';
import 'package:flutter_muxpod/services/mux/psmux_backend.dart';

/// Minimal in-memory [CommandExecutor] used in tests.
class _MockExecutor implements CommandExecutor {
  /// Commands captured by [execute], in order.
  final List<String> capturedCommands = [];

  /// Queue of responses returned by [execute] in FIFO order.
  final List<String> responses;

  _MockExecutor(this.responses);

  @override
  Future<String> execute(String command) async {
    capturedCommands.add(command);
    if (responses.isNotEmpty) {
      return responses.removeAt(0);
    }
    return '';
  }

  @override
  Future<Stream<List<int>>> shell() async => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Test helpers — raw psmux / tmux output lines using the ||| delimiter.
// ---------------------------------------------------------------------------

/// One session line: name|||created_epoch|||attached|||windows|||id
const _sessionLine = 'main|||1700000000|||1|||2|||\$1';

/// One window line: index|||id|||name|||active|||panes|||flags
const _windowLine = '0|||@1|||bash|||1|||1|||*';

/// One pane line: index|||id|||active|||command|||title|||width|||height|||cx|||cy
const _paneLine = '0|||%1|||1|||bash|||bash|||80|||24|||0|||0';

void main() {
  group('PsmuxBackend', () {
    test('name returns "psmux"', () {
      final backend = PsmuxBackend(_MockExecutor([]));
      expect(backend.name, equals('psmux'));
    });

    // -------------------------------------------------------------------------
    // Command prefix substitution
    // -------------------------------------------------------------------------

    test('listSessions sends a psmux command, not tmux', () async {
      final executor = _MockExecutor([_sessionLine]);
      final backend = PsmuxBackend(executor);
      await backend.listSessions();

      expect(executor.capturedCommands, hasLength(1));
      final cmd = executor.capturedCommands.first;
      expect(cmd, startsWith('psmux '));
      expect(cmd, isNot(startsWith('tmux ')));
    });

    test('listWindows sends a psmux command', () async {
      final executor = _MockExecutor([_windowLine]);
      final backend = PsmuxBackend(executor);
      await backend.listWindows('main');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('listPanes sends a psmux command', () async {
      final executor = _MockExecutor([_paneLine]);
      final backend = PsmuxBackend(executor);
      await backend.listPanes('main:0');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('sendKeys sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.sendKeys('%1', 'ls');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('capturePane sends a psmux command', () async {
      final executor = _MockExecutor(['hello world']);
      final backend = PsmuxBackend(executor);
      await backend.capturePane('%1');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('splitPane sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.splitPane('main:0', horizontal: true);

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('selectPane sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.selectPane('main:0', 1);

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('killSession sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.killSession('main');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('attachSession sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.attachSession('main');

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    test('selectWindow sends a psmux command', () async {
      final executor = _MockExecutor(['']);
      final backend = PsmuxBackend(executor);
      await backend.selectWindow('main', 1);

      expect(executor.capturedCommands.first, startsWith('psmux '));
    });

    // -------------------------------------------------------------------------
    // Output parsing
    // -------------------------------------------------------------------------

    test('listSessions parses output into MuxSession list', () async {
      final executor = _MockExecutor([_sessionLine]);
      final backend = PsmuxBackend(executor);
      final sessions = await backend.listSessions();

      expect(sessions, hasLength(1));
      expect(sessions.first, isA<MuxSession>());
      expect(sessions.first.name, equals('main'));
      expect(sessions.first.attached, isTrue);
      expect(sessions.first.windowCount, equals(2));
    });

    test('listWindows parses output into MuxWindow list', () async {
      final executor = _MockExecutor([_windowLine]);
      final backend = PsmuxBackend(executor);
      final windows = await backend.listWindows('main');

      expect(windows, hasLength(1));
      expect(windows.first, isA<MuxWindow>());
      expect(windows.first.index, equals(0));
      expect(windows.first.name, equals('bash'));
      expect(windows.first.active, isTrue);
    });

    test('listPanes parses output into MuxPane list', () async {
      final executor = _MockExecutor([_paneLine]);
      final backend = PsmuxBackend(executor);
      final panes = await backend.listPanes('main:0');

      expect(panes, hasLength(1));
      expect(panes.first, isA<MuxPane>());
      expect(panes.first.index, equals(0));
      expect(panes.first.id, equals('%1'));
      expect(panes.first.active, isTrue);
      expect(panes.first.width, equals(80));
      expect(panes.first.height, equals(24));
    });

    test('capturePane returns raw output from executor', () async {
      const content = 'some terminal output\nsecond line';
      final executor = _MockExecutor([content]);
      final backend = PsmuxBackend(executor);
      final result = await backend.capturePane('%1');

      expect(result, equals(content));
    });

    test('listSessions returns empty list when server is not running', () async {
      final executor = _MockExecutor(['no server running']);
      final backend = PsmuxBackend(executor);
      final sessions = await backend.listSessions();

      expect(sessions, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Nesting
    // -------------------------------------------------------------------------

    test('getNestedBackend returns null', () async {
      final executor = _MockExecutor([]);
      final backend = PsmuxBackend(executor);
      final nested = await backend.getNestedBackend('%1');

      expect(nested, isNull);
    });

    // -------------------------------------------------------------------------
    // newSession
    // -------------------------------------------------------------------------

    test('newSession creates session and returns it from listSessions', () async {
      // First call (new-session) returns '', second (list-sessions) returns the
      // new session line.
      final executor = _MockExecutor(['', 'mysession|||1700000001|||0|||1|||\$2']);
      final backend = PsmuxBackend(executor);
      final session = await backend.newSession(name: 'mysession');

      expect(session.name, equals('mysession'));
      // Both commands must use psmux prefix.
      for (final cmd in executor.capturedCommands) {
        expect(cmd, startsWith('psmux '));
      }
    });

    // -------------------------------------------------------------------------
    // newWindow
    // -------------------------------------------------------------------------

    test('newWindow creates window and returns highest-index window', () async {
      final executor = _MockExecutor(['', _windowLine]);
      final backend = PsmuxBackend(executor);
      final window = await backend.newWindow('main');

      expect(window, isA<MuxWindow>());
      for (final cmd in executor.capturedCommands) {
        expect(cmd, startsWith('psmux '));
      }
    });
  });
}
