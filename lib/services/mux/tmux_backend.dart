import 'dart:convert';
import 'dart:typed_data';

import '../tmux/tmux_commands.dart';
import '../tmux/tmux_parser.dart';
import 'command_executor.dart';
import 'mux_backend.dart';
import 'mux_models.dart';
import 'mux_pty_session.dart';

/// [MuxBackend] implementation that wraps [TmuxCommands] and [TmuxParser].
///
/// Delegates command generation to the static [TmuxCommands] utilities,
/// execution to the injected [CommandExecutor], and output parsing to the
/// static [TmuxParser] utilities.  Results are mapped from the tmux-specific
/// model classes ([TmuxSession], [TmuxWindow], [TmuxPane]) to the unified
/// [MuxSession], [MuxWindow], [MuxPane] models.
class TmuxBackend implements MuxBackend {
  TmuxBackend(this._executor);

  final CommandExecutor _executor;

  @override
  String get name => 'tmux';

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  @override
  Future<List<MuxSession>> listSessions() async {
    final output = await _executor.execute(TmuxCommands.listSessions());
    final tmuxSessions = TmuxParser.parseSessions(output);
    return tmuxSessions.map(_mapSession).toList();
  }

  @override
  Future<MuxSession> newSession({String? name}) async {
    final sessionName = name ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
    await _executor.execute(
      TmuxCommands.newSession(name: sessionName, detached: true),
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
    await _executor.execute(TmuxCommands.killSession(sessionId));
  }

  @override
  Future<void> attachSession(String sessionId) async {
    await _executor.execute(TmuxCommands.attachSession(sessionId));
  }

  // ---------------------------------------------------------------------------
  // Windows
  // ---------------------------------------------------------------------------

  @override
  Future<List<MuxWindow>> listWindows(String sessionId) async {
    final output = await _executor.execute(TmuxCommands.listWindows(sessionId));
    final tmuxWindows = TmuxParser.parseWindows(output);
    return tmuxWindows.map(_mapWindow).toList();
  }

  @override
  Future<MuxWindow> newWindow(String sessionId, {String? name}) async {
    await _executor.execute(
      TmuxCommands.newWindow(sessionName: sessionId, windowName: name),
    );
    // Retrieve updated window list and return the last (newest) window.
    final windows = await listWindows(sessionId);
    if (windows.isNotEmpty) {
      // The newly created window is typically the one with the highest index.
      final sorted = [...windows]..sort((a, b) => b.index.compareTo(a.index));
      return sorted.first;
    }
    // Fallback
    return MuxWindow(index: 0, id: '', name: name ?? 'window');
  }

  @override
  Future<void> selectWindow(String sessionId, int index) async {
    await _executor.execute(TmuxCommands.selectWindow(sessionId, index));
  }

  // ---------------------------------------------------------------------------
  // Panes
  // ---------------------------------------------------------------------------

  /// [windowTarget] format: "sessionName:windowIndex"
  @override
  Future<List<MuxPane>> listPanes(String windowTarget) async {
    final (sessionName, windowIndex) = _parseWindowTarget(windowTarget);
    final output = await _executor.execute(
      TmuxCommands.listPanes(sessionName, windowIndex),
    );
    final tmuxPanes = TmuxParser.parsePanes(output);
    return tmuxPanes.map(_mapPane).toList();
  }

  @override
  Future<void> splitPane(String target, {bool horizontal = true}) async {
    final command = horizontal
        ? TmuxCommands.splitWindowHorizontal(target: target)
        : TmuxCommands.splitWindowVertical(target: target);
    await _executor.execute(command);
  }

  @override
  Future<void> selectPane(String target, int index) async {
    await _executor.execute(TmuxCommands.selectPane('$target.$index'));
  }

  // ---------------------------------------------------------------------------
  // I/O
  // ---------------------------------------------------------------------------

  @override
  Future<String> capturePane(String target) async {
    return _executor.execute(TmuxCommands.capturePane(target));
  }

  @override
  Future<void> sendKeys(String target, String keys) async {
    await _executor.execute(TmuxCommands.sendKeys(target, keys));
  }

  // ---------------------------------------------------------------------------
  // Nesting
  // ---------------------------------------------------------------------------

  @override
  Future<MuxBackend?> getNestedBackend(String paneTarget) async {
    // tmux does not support nesting in this architecture.
    return null;
  }

  // ---------------------------------------------------------------------------
  // PTY
  // ---------------------------------------------------------------------------

  @override
  Future<MuxPtySession> attachPty(String sessionId) async {
    final shell = await _executor.openInteractiveShell();

    // Wait briefly for shell to initialize before sending attach command
    await Future.delayed(const Duration(milliseconds: 100));

    // Send the tmux attach command through the PTY (using TmuxCommands for proper escaping)
    final attachCmd = TmuxCommands.attachSession(sessionId);
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
        id: (w.id?.isNotEmpty == true) ? w.id! : w.index.toString(),
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
