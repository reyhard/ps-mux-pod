import 'mux_models.dart';
import 'mux_pty_session.dart';

/// Abstract interface for terminal multiplexer backends.
///
/// Implementations wrap specific multiplexers (tmux, psmux) while
/// exposing a unified API for session/window/pane management.
abstract class MuxBackend {
  /// Backend identifier ("tmux" or "psmux").
  String get name;

  // --- Sessions ---

  Future<List<MuxSession>> listSessions();
  Future<MuxSession> newSession({String? name});
  Future<void> killSession(String sessionId);
  Future<void> attachSession(String sessionId);

  // --- Windows ---

  Future<List<MuxWindow>> listWindows(String sessionId);
  Future<MuxWindow> newWindow(String sessionId, {String? name});
  Future<void> selectWindow(String sessionId, int index);

  // --- Panes ---

  Future<List<MuxPane>> listPanes(String windowTarget);
  Future<void> splitPane(String target, {bool horizontal = true});
  Future<void> selectPane(String target, int index);

  // --- I/O ---

  Future<String> capturePane(String target);
  Future<void> sendKeys(String target, String keys);

  // --- Nesting ---

  /// Returns a nested backend discovered inside a pane, or null.
  Future<MuxBackend?> getNestedBackend(String paneTarget);

  // --- PTY ---

  /// Open a real-time PTY session attached to the given session.
  Future<MuxPtySession> attachPty(String sessionId);
}
