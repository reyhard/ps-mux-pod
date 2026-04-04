import 'dart:convert';
import 'dart:typed_data';

import '../tmux/tmux_commands.dart';
import '../tmux/tmux_parser.dart';
import 'command_executor.dart';
import 'mux_backend.dart';
import 'mux_models.dart';
import 'mux_pty_session.dart';

/// [MuxBackend] implementation for psmux.
///
/// psmux is command-compatible with tmux, so this backend delegates command
/// generation to [TmuxCommands] and parsing to [TmuxParser], substituting
/// the leading "tmux" token with "psmux" before execution.
class PsmuxBackend implements MuxBackend {
  PsmuxBackend(this._executor);

  final CommandExecutor _executor;

  @override
  String get name => 'psmux';

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  @override
  Future<List<MuxSession>> listSessions() async {
    final output = await _executor.execute(
      _toPsmuxCommand(TmuxCommands.listSessions()),
    );
    final sessions = TmuxParser.parseSessions(output);
    return sessions.map(_mapSession).toList();
  }

  @override
  Future<MuxSession> newSession({String? name}) async {
    final sessionName = name ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.newSession(name: sessionName, detached: true)),
    );
    // Retrieve the freshly-created session so we can return accurate metadata.
    final sessions = await listSessions();
    final created = sessions.where((s) => s.name == sessionName).firstOrNull;
    if (created != null) return created;
    // Fallback: construct a minimal session if the list-sessions call did not
    // yet reflect the new session (race condition on slow hosts).
    return MuxSession(id: sessionName, name: sessionName);
  }

  @override
  Future<void> killSession(String sessionId) async {
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.killSession(sessionId)),
    );
  }

  @override
  Future<void> attachSession(String sessionId) async {
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.attachSession(sessionId)),
    );
  }

  // ---------------------------------------------------------------------------
  // Windows
  // ---------------------------------------------------------------------------

  @override
  Future<List<MuxWindow>> listWindows(String sessionId) async {
    final output = await _executor.execute(
      _toPsmuxCommand(TmuxCommands.listWindows(sessionId)),
    );
    final windows = TmuxParser.parseWindows(output);
    return windows.map(_mapWindow).toList();
  }

  @override
  Future<MuxWindow> newWindow(String sessionId, {String? name}) async {
    await _executor.execute(
      _toPsmuxCommand(
        TmuxCommands.newWindow(sessionName: sessionId, windowName: name),
      ),
    );
    // Retrieve updated window list and return the last (newest) window.
    final windows = await listWindows(sessionId);
    if (windows.isNotEmpty) {
      final sorted = [...windows]..sort((a, b) => b.index.compareTo(a.index));
      return sorted.first;
    }
    // Fallback
    return MuxWindow(index: 0, id: '', name: name ?? 'window');
  }

  @override
  Future<void> selectWindow(String sessionId, int index) async {
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.selectWindow(sessionId, index)),
    );
  }

  // ---------------------------------------------------------------------------
  // Panes
  // ---------------------------------------------------------------------------

  /// [windowTarget] format: "sessionName:windowIndex"
  @override
  Future<List<MuxPane>> listPanes(String windowTarget) async {
    final (sessionName, windowIndex) = _parseWindowTarget(windowTarget);
    final output = await _executor.execute(
      _toPsmuxCommand(TmuxCommands.listPanes(sessionName, windowIndex)),
    );
    final panes = TmuxParser.parsePanes(output);
    return panes.map(_mapPane).toList();
  }

  @override
  Future<void> splitPane(String target, {bool horizontal = true}) async {
    final command = horizontal
        ? TmuxCommands.splitWindowHorizontal(target: target)
        : TmuxCommands.splitWindowVertical(target: target);
    await _executor.execute(_toPsmuxCommand(command));
  }

  @override
  Future<void> selectPane(String target, int index) async {
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.selectPane('$target.$index')),
    );
  }

  // ---------------------------------------------------------------------------
  // I/O
  // ---------------------------------------------------------------------------

  @override
  Future<String> capturePane(String target) async {
    return _executor.execute(
      _toPsmuxCommand(TmuxCommands.capturePane(target)),
    );
  }

  @override
  Future<void> sendKeys(String target, String keys) async {
    await _executor.execute(
      _toPsmuxCommand(TmuxCommands.sendKeys(target, keys)),
    );
  }

  // ---------------------------------------------------------------------------
  // Nesting
  // ---------------------------------------------------------------------------

  /// Returns a nested backend discovered inside a pane, or null.
  ///
  /// Nesting support (e.g. tmux inside WSL panes) is wired at integration time;
  /// this implementation always returns null.
  @override
  Future<MuxBackend?> getNestedBackend(String paneTarget) async {
    return null;
  }

  // ---------------------------------------------------------------------------
  // PTY
  // ---------------------------------------------------------------------------

  @override
  Future<MuxPtySession> attachPty(String sessionId) async {
    final shell = await _executor.openInteractiveShell();

    final attachCmd = _toPsmuxCommand(TmuxCommands.attachSession(sessionId));
    shell.write(Uint8List.fromList(utf8.encode('$attachCmd\n')));

    return MuxPtySession(
      stdout: shell.stdout,
      write: shell.write,
      resize: shell.resize,
      close: shell.close,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Substitutes the leading "tmux " token with "psmux " in a tmux command
  /// string, making it suitable for execution by psmux.
  String _toPsmuxCommand(String tmuxCommand) {
    return tmuxCommand.replaceFirst('tmux ', 'psmux ');
  }

  /// Parses a window target of the form "sessionName:windowIndex".
  ///
  /// Falls back to index 0 when the index part is absent or non-numeric.
  (String sessionName, int windowIndex) _parseWindowTarget(String windowTarget) {
    final colon = windowTarget.lastIndexOf(':');
    if (colon == -1) return (windowTarget, 0);
    final sessionName = windowTarget.substring(0, colon);
    final indexStr = windowTarget.substring(colon + 1);
    final windowIndex = int.tryParse(indexStr) ?? 0;
    return (sessionName, windowIndex);
  }

  MuxSession _mapSession(TmuxSession s) => MuxSession(
        id: s.id ?? s.name,
        name: s.name,
        created: s.created,
        attached: s.attached,
        windowCount: s.windowCount,
      );

  MuxWindow _mapWindow(TmuxWindow w) => MuxWindow(
        index: w.index,
        id: w.id ?? w.index.toString(),
        name: w.name,
        active: w.active,
        paneCount: w.paneCount,
      );

  MuxPane _mapPane(TmuxPane p) => MuxPane(
        index: p.index,
        id: p.id,
        active: p.active,
        currentCommand: p.currentCommand,
        width: p.width,
        height: p.height,
      );
}
