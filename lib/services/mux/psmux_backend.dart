import 'dart:async';
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
  PsmuxBackend(
    this._executor, {
    Duration? shellPromptTimeout,
  }) : _shellPromptTimeout =
           shellPromptTimeout ?? const Duration(seconds: 5);

  final CommandExecutor _executor;
  final Duration _shellPromptTimeout;

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
    final sessions = TmuxParser.parseSessions(_sanitizeStructuredOutput(output));
    return sessions.map(_mapSession).toList();
  }

  @override
  Future<MuxSession> newSession({String? name}) async {
    final sessionName = name ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
    final cmd = _toPsmuxCommand(TmuxCommands.newSession(name: sessionName, detached: true));
    // ignore: avoid_print
    print('[psmux] newSession cmd: $cmd');
    final output = await _executor.execute(cmd);
    // ignore: avoid_print
    print('[psmux] newSession output: "$output"');

    // Try to retrieve the freshly-created session.
    try {
      final sessions = await listSessions();
      final created = sessions.where((s) => s.name == sessionName).firstOrNull;
      if (created != null) return created;
    } catch (_) {
      // List may fail on Windows/psmux — fall through to minimal session.
    }
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
    final windows = TmuxParser.parseWindows(_sanitizeStructuredOutput(output));
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
    final panes = TmuxParser.parsePanes(_sanitizeStructuredOutput(output));
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

    // Try to attach to an existing session; if it doesn't exist, create one.
    // Uses PowerShell 7 `||` operator. The new-session (without -d) creates
    // AND attaches in a single step, keeping the psmux server alive inside
    // this shell.
    final attachOrCreate =
        'psmux attach-session -t $sessionId 2>\$null'
        ' || psmux new-session -s $sessionId';

    final controller = StreamController<List<int>>();
    final promptCompleter = Completer<void>();
    var promptBuffer = '';

    shell.stdout.listen(
      (data) {
        if (!promptCompleter.isCompleted) {
          promptBuffer += utf8.decode(data, allowMalformed: true);
          if (promptBuffer.length > 512) {
            promptBuffer = promptBuffer.substring(promptBuffer.length - 512);
          }
          if (_looksLikeShellPrompt(promptBuffer)) {
            shell.write(Uint8List.fromList(utf8.encode('$attachOrCreate\r')));
            promptCompleter.complete();
          }
        }
        if (!controller.isClosed) controller.add(data);
      },
      onError: (e) { if (!controller.isClosed) controller.addError(e); },
      onDone: () { if (!controller.isClosed) controller.close(); },
    );

    Future.delayed(_shellPromptTimeout, () {
      if (!promptCompleter.isCompleted) promptCompleter.complete();
    });

    await promptCompleter.future;

    return MuxPtySession(
      stdout: controller.stream,
      write: shell.write,
      resize: shell.resize,
      close: () async {
        controller.close();
        await shell.close();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Translates a tmux command string for psmux on Windows/PowerShell.
  ///
  /// Replaces the leading "tmux" token with "psmux" and adapts bash-isms
  /// (e.g. `2>/dev/null`) to PowerShell equivalents (`2>$null`).
  String _toPsmuxCommand(String tmuxCommand) {
    return tmuxCommand
        .replaceFirst('tmux ', 'psmux ')
        .replaceAll('2>/dev/null', r'2>$null')
        .replaceAll('2>&1', '2>&1');
  }

  /// Strips shell noise (MOTD, keep-alive messages, etc.) from command output,
  /// keeping only lines that look like psmux structured data.
  String _sanitizeStructuredOutput(String output) {
    final lines = output.split(RegExp(r'[\r\n]+'));
    return lines.where((line) => line.contains('|||')).join('\n');
  }

  bool _looksLikeShellPrompt(String text) {
    final normalized = text.replaceAll('\r', '\n');
    final match = RegExp(r'(^|\n)[^\n]*[>#$] ?$').firstMatch(normalized);
    return match != null;
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
