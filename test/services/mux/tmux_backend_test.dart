import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/command_executor.dart';
import 'package:flutter_muxpod/services/mux/tmux_backend.dart';

// ---------------------------------------------------------------------------
// Minimal mock CommandExecutor
// ---------------------------------------------------------------------------

class _MockExecutor implements CommandExecutor {
  /// Records every command string passed to [execute].
  final List<String> executedCommands = [];

  /// Maps a command prefix (or full command) to the output to return.
  final Map<String, String> responses;

  /// Default response when no key matches.
  final String defaultResponse;

  _MockExecutor({
    this.responses = const {},
    this.defaultResponse = '',
  });

  @override
  Future<String> execute(String command) async {
    executedCommands.add(command);
    for (final entry in responses.entries) {
      if (command.contains(entry.key)) {
        return entry.value;
      }
    }
    return defaultResponse;
  }

  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    throw UnimplementedError('Not needed for tmux backend tests');
  }

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Helpers that generate realistic tmux output using the ||| delimiter
// ---------------------------------------------------------------------------

const _d = '|||'; // TmuxCommands.delimiter / TmuxParser.defaultDelimiter

String _sessionLine({
  required String name,
  String? id,
  int created = 1700000000,
  int attached = 0,
  int windows = 1,
}) =>
    '$name$_d$created$_d$attached$_d$windows$_d${id ?? '\$1'}';

String _windowLine({
  required int index,
  String? id,
  required String name,
  int active = 0,
  int panes = 1,
  String flags = '',
}) =>
    '$index$_d${id ?? '@$index'}$_d$name$_d$active$_d$panes$_d$flags';

String _paneLine({
  required int index,
  required String id,
  int active = 0,
  String command = 'bash',
  String title = '',
  int width = 80,
  int height = 24,
  int cursorX = 0,
  int cursorY = 0,
}) =>
    '$index$_d$id$_d$active$_d$command$_d$title$_d$width$_d$height$_d$cursorX$_d$cursorY';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TmuxBackend.name', () {
    test('returns "tmux"', () {
      final backend = TmuxBackend(_MockExecutor());
      expect(backend.name, 'tmux');
    });
  });

  // -------------------------------------------------------------------------
  // listSessions
  // -------------------------------------------------------------------------

  group('TmuxBackend.listSessions', () {
    test('returns empty list when no sessions exist', () async {
      final executor = _MockExecutor(defaultResponse: '');
      final backend = TmuxBackend(executor);

      final sessions = await backend.listSessions();

      expect(sessions, isEmpty);
      expect(executor.executedCommands, hasLength(1));
      expect(executor.executedCommands.first, contains('list-sessions'));
    });

    test('parses multiple sessions into MuxSession objects', () async {
      final output = [
        _sessionLine(name: 'main', id: '\$1', attached: 1, windows: 3),
        _sessionLine(name: 'work', id: '\$2', attached: 0, windows: 2),
      ].join('\n');

      final executor = _MockExecutor(responses: {'list-sessions': output});
      final backend = TmuxBackend(executor);

      final sessions = await backend.listSessions();

      expect(sessions, hasLength(2));

      final main = sessions.firstWhere((s) => s.name == 'main');
      expect(main.id, '\$1');
      expect(main.attached, isTrue);
      expect(main.windowCount, 3);

      final work = sessions.firstWhere((s) => s.name == 'work');
      expect(work.id, '\$2');
      expect(work.attached, isFalse);
      expect(work.windowCount, 2);
    });

    test('passes correct list-sessions command to executor', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).listSessions();

      expect(executor.executedCommands.first, contains('tmux list-sessions'));
    });
  });

  // -------------------------------------------------------------------------
  // newSession
  // -------------------------------------------------------------------------

  group('TmuxBackend.newSession', () {
    test('creates session with given name and returns it', () async {
      const sessionName = 'alpha';
      final listOutput = _sessionLine(name: sessionName, id: '\$10', windows: 1);

      final executor = _MockExecutor(
        responses: {'list-sessions': listOutput},
      );
      final backend = TmuxBackend(executor);

      final session = await backend.newSession(name: sessionName);

      expect(session.name, sessionName);
      expect(session.id, '\$10');
      // new-session command must have been issued before list-sessions
      final newSessionCmd = executor.executedCommands.firstWhere(
        (c) => c.contains('new-session'),
      );
      expect(newSessionCmd, contains('-s'));
      expect(newSessionCmd, contains(sessionName));
    });

    test('passes detached flag to new-session command', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).newSession(name: 'beta');

      final cmd = executor.executedCommands.firstWhere(
        (c) => c.contains('new-session'),
      );
      expect(cmd, contains('-d'));
    });
  });

  // -------------------------------------------------------------------------
  // killSession
  // -------------------------------------------------------------------------

  group('TmuxBackend.killSession', () {
    test('executes kill-session with the session id', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).killSession('main');

      expect(executor.executedCommands, hasLength(1));
      expect(executor.executedCommands.first, contains('kill-session'));
      expect(executor.executedCommands.first, contains('main'));
    });
  });

  // -------------------------------------------------------------------------
  // listWindows
  // -------------------------------------------------------------------------

  group('TmuxBackend.listWindows', () {
    test('passes session name to list-windows command', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).listWindows('main');

      expect(executor.executedCommands.first, contains('list-windows'));
      expect(executor.executedCommands.first, contains('main'));
    });

    test('parses windows into MuxWindow objects', () async {
      final output = [
        _windowLine(index: 0, id: '@0', name: 'editor', active: 1, panes: 2),
        _windowLine(index: 1, id: '@1', name: 'shell', active: 0, panes: 1),
      ].join('\n');

      final executor = _MockExecutor(responses: {'list-windows': output});
      final backend = TmuxBackend(executor);

      final windows = await backend.listWindows('main');

      expect(windows, hasLength(2));

      final editor = windows.firstWhere((w) => w.name == 'editor');
      expect(editor.index, 0);
      expect(editor.id, '@0');
      expect(editor.active, isTrue);
      expect(editor.paneCount, 2);

      final shell = windows.firstWhere((w) => w.name == 'shell');
      expect(shell.index, 1);
      expect(shell.active, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // newWindow
  // -------------------------------------------------------------------------

  group('TmuxBackend.newWindow', () {
    test('executes new-window with session name', () async {
      final listOutput = _windowLine(index: 0, name: 'new');
      final executor = _MockExecutor(responses: {'list-windows': listOutput});
      await TmuxBackend(executor).newWindow('main', name: 'new');

      final cmd = executor.executedCommands.firstWhere(
        (c) => c.contains('new-window'),
      );
      expect(cmd, contains('main'));
    });
  });

  // -------------------------------------------------------------------------
  // listPanes
  // -------------------------------------------------------------------------

  group('TmuxBackend.listPanes', () {
    test('parses windowTarget "session:index" and queries correct panes', () async {
      final output = [
        _paneLine(index: 0, id: '%0', active: 1, command: 'vim'),
        _paneLine(index: 1, id: '%1', active: 0, command: 'bash'),
      ].join('\n');

      final executor = _MockExecutor(responses: {'list-panes': output});
      final backend = TmuxBackend(executor);

      final panes = await backend.listPanes('main:0');

      expect(panes, hasLength(2));

      final vim = panes.firstWhere((p) => p.id == '%0');
      expect(vim.index, 0);
      expect(vim.active, isTrue);
      expect(vim.currentCommand, 'vim');

      final bash = panes.firstWhere((p) => p.id == '%1');
      expect(bash.index, 1);
      expect(bash.active, isFalse);
      expect(bash.currentCommand, 'bash');
    });

    test('command includes session name and window index', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).listPanes('mysession:2');

      expect(executor.executedCommands.first, contains('list-panes'));
      expect(executor.executedCommands.first, contains('mysession'));
      expect(executor.executedCommands.first, contains('2'));
    });

    test('defaults to window index 0 when windowTarget has no colon', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).listPanes('mysession');

      expect(executor.executedCommands.first, contains('list-panes'));
      expect(executor.executedCommands.first, contains('mysession'));
    });

    test('maps pane dimensions correctly', () async {
      final output = _paneLine(
        index: 0,
        id: '%5',
        width: 120,
        height: 40,
      );

      final executor = _MockExecutor(responses: {'list-panes': output});
      final panes = await TmuxBackend(executor).listPanes('s:0');

      expect(panes.single.width, 120);
      expect(panes.single.height, 40);
    });
  });

  // -------------------------------------------------------------------------
  // splitPane
  // -------------------------------------------------------------------------

  group('TmuxBackend.splitPane', () {
    test('uses split-window -h for horizontal splits', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).splitPane('%1', horizontal: true);

      expect(executor.executedCommands.first, contains('split-window'));
      expect(executor.executedCommands.first, contains('-h'));
    });

    test('uses split-window -v for vertical splits', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).splitPane('%1', horizontal: false);

      expect(executor.executedCommands.first, contains('split-window'));
      expect(executor.executedCommands.first, contains('-v'));
    });
  });

  // -------------------------------------------------------------------------
  // capturePane
  // -------------------------------------------------------------------------

  group('TmuxBackend.capturePane', () {
    test('returns raw output from executor', () async {
      const expected = '\x1b[32mhello\x1b[0m world';
      final executor = _MockExecutor(
        responses: {'capture-pane': expected},
      );

      final result = await TmuxBackend(executor).capturePane('%0');

      expect(result, expected);
    });

    test('passes pane id to capture-pane command', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).capturePane('%42');

      expect(executor.executedCommands.first, contains('capture-pane'));
      expect(executor.executedCommands.first, contains('%42'));
    });
  });

  // -------------------------------------------------------------------------
  // sendKeys
  // -------------------------------------------------------------------------

  group('TmuxBackend.sendKeys', () {
    test('passes target and keys to send-keys command', () async {
      final executor = _MockExecutor();
      await TmuxBackend(executor).sendKeys('%3', 'ls -la');

      expect(executor.executedCommands, hasLength(1));
      final cmd = executor.executedCommands.first;
      expect(cmd, contains('send-keys'));
      expect(cmd, contains('%3'));
      expect(cmd, contains('ls -la'));
    });
  });

  // -------------------------------------------------------------------------
  // getNestedBackend
  // -------------------------------------------------------------------------

  group('TmuxBackend.getNestedBackend', () {
    test('always returns null', () async {
      final backend = TmuxBackend(_MockExecutor());
      final nested = await backend.getNestedBackend('%0');
      expect(nested, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // MuxSession / MuxWindow / MuxPane field mapping
  // -------------------------------------------------------------------------

  group('Model mapping', () {
    test('MuxSession.created is populated from tmux timestamp', () async {
      final output = _sessionLine(name: 's', created: 1700000000);
      final executor = _MockExecutor(responses: {'list-sessions': output});

      final sessions = await TmuxBackend(executor).listSessions();

      expect(sessions.single.created, isNotNull);
      expect(
        sessions.single.created!.millisecondsSinceEpoch,
        1700000000 * 1000,
      );
    });

    test('MuxPane.currentCommand is forwarded correctly', () async {
      final output = _paneLine(index: 0, id: '%9', command: 'nvim');
      final executor = _MockExecutor(responses: {'list-panes': output});

      final panes = await TmuxBackend(executor).listPanes('s:0');

      expect(panes.single.currentCommand, 'nvim');
    });

    test('MuxWindow falls back to index string when id is absent', () async {
      // Produce a window line without an explicit id (empty second field)
      final output = '0$_d${_d}noname${_d}0${_d}1$_d';
      final executor = _MockExecutor(responses: {'list-windows': output});

      final windows = await TmuxBackend(executor).listWindows('s');

      expect(windows.single.id, '0');
    });
  });
}
