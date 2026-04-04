import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tmux/tmux_parser.dart';

/// Tmux state
class TmuxState {
  final List<TmuxSession> sessions;
  final String? activeSessionName;
  final int? activeWindowIndex;
  final int? activePaneIndex;
  final String? activePaneId;
  final bool isLoading;
  final String? error;

  const TmuxState({
    this.sessions = const [],
    this.activeSessionName,
    this.activeWindowIndex,
    this.activePaneIndex,
    this.activePaneId,
    this.isLoading = false,
    this.error,
  });

  TmuxState copyWith({
    List<TmuxSession>? sessions,
    String? activeSessionName,
    int? activeWindowIndex,
    int? activePaneIndex,
    String? activePaneId,
    bool? isLoading,
    String? error,
    bool clearActiveWindowIndex = false,
    bool clearActivePaneIndex = false,
    bool clearActivePaneId = false,
  }) {
    return TmuxState(
      sessions: sessions ?? this.sessions,
      activeSessionName: activeSessionName ?? this.activeSessionName,
      activeWindowIndex: clearActiveWindowIndex ? null : (activeWindowIndex ?? this.activeWindowIndex),
      activePaneIndex: clearActivePaneIndex ? null : (activePaneIndex ?? this.activePaneIndex),
      activePaneId: clearActivePaneId ? null : (activePaneId ?? this.activePaneId),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get the active session
  TmuxSession? get activeSession {
    if (activeSessionName == null) return null;
    try {
      return sessions.firstWhere((s) => s.name == activeSessionName);
    } catch (e) {
      return null;
    }
  }

  /// Get the active window
  TmuxWindow? get activeWindow {
    final session = activeSession;
    if (session == null || activeWindowIndex == null) return null;
    try {
      return session.windows.firstWhere((w) => w.index == activeWindowIndex);
    } catch (e) {
      return null;
    }
  }

  /// Get the active pane
  TmuxPane? get activePane {
    final window = activeWindow;
    if (window == null || activePaneId == null) return null;
    try {
      return window.panes.firstWhere((p) => p.id == activePaneId);
    } catch (e) {
      return null;
    }
  }
}

/// Notifier that manages Tmux sessions
class TmuxNotifier extends Notifier<TmuxState> {
  @override
  TmuxState build() {
    return const TmuxState();
  }

  /// Update the session list
  void updateSessions(List<TmuxSession> sessions) {
    state = state.copyWith(sessions: sessions, error: null);
  }

  /// Parse and update the session list
  void parseAndUpdateSessions(String output) {
    try {
      final sessions = TmuxParser.parseSessions(output);
      state = state.copyWith(sessions: sessions, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Parse and update the full tree
  void parseAndUpdateFullTree(String output) {
    try {
      final sessions = TmuxParser.parseFullTree(output);
      state = state.copyWith(sessions: sessions, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Set the active session
  void setActiveSession(String sessionName) {
    // Automatically select the first active window and pane in the session
    final session = state.sessions.where((s) => s.name == sessionName).firstOrNull;
    final activeWindow = session?.windows.where((w) => w.active).firstOrNull ?? session?.windows.firstOrNull;
    final activePane = activeWindow?.panes.where((p) => p.active).firstOrNull ?? activeWindow?.panes.firstOrNull;

    state = state.copyWith(
      activeSessionName: sessionName,
      activeWindowIndex: activeWindow?.index,
      activePaneIndex: activePane?.index,
      activePaneId: activePane?.id,
      clearActiveWindowIndex: activeWindow == null,
      clearActivePaneIndex: activePane == null,
      clearActivePaneId: activePane == null,
    );
  }

  /// Set the active window
  void setActiveWindow(int windowIndex) {
    // Automatically select the first active pane in the window
    final session = state.activeSession;
    final window = session?.windows.where((w) => w.index == windowIndex).firstOrNull;
    final activePane = window?.panes.where((p) => p.active).firstOrNull ?? window?.panes.firstOrNull;

    state = state.copyWith(
      activeWindowIndex: windowIndex,
      activePaneIndex: activePane?.index,
      activePaneId: activePane?.id,
      clearActivePaneIndex: activePane == null,
      clearActivePaneId: activePane == null,
    );
  }

  /// Set the active pane by pane index
  void setActivePaneByIndex(int paneIndex, {String? paneId}) {
    state = state.copyWith(
      activePaneIndex: paneIndex,
      activePaneId: paneId,
    );
  }

  /// Set the active pane by pane ID
  void setActivePane(String paneId) {
    // Get the index from paneId
    final window = state.activeWindow;
    final pane = window?.panes.where((p) => p.id == paneId).firstOrNull;
    state = state.copyWith(
      activePaneId: paneId,
      activePaneIndex: pane?.index,
    );
  }

  /// Update the cursor position
  void updateCursorPosition(String paneId, int x, int y) {
    // Skip if nothing changed to avoid deep-copying
    final currentPane = state.activePane;
    if (currentPane == null || currentPane.id != paneId) return;
    if (currentPane.cursorX == x && currentPane.cursorY == y) return;

    final sessions = state.sessions.map((session) {
      final windows = session.windows.map((window) {
        final panes = window.panes.map((pane) {
          if (pane.id == paneId) {
            return pane.copyWith(cursorX: x, cursorY: y);
          }
          return pane;
        }).toList();
        return window.copyWith(panes: panes);
      }).toList();
      return session.copyWith(windows: windows);
    }).toList();

    state = state.copyWith(sessions: sessions);
  }

  /// Set the active session/window/pane together
  void setActive({
    String? sessionName,
    int? windowIndex,
    int? paneIndex,
    String? paneId,
  }) {
    state = state.copyWith(
      activeSessionName: sessionName,
      activeWindowIndex: windowIndex,
      activePaneIndex: paneIndex,
      activePaneId: paneId,
    );
  }

  /// Get the current tmux target string used for polling
  /// format: session:window.pane
  String? get currentTarget {
    final session = state.activeSessionName;
    final window = state.activeWindowIndex;
    final pane = state.activePaneIndex;
    if (session == null || window == null || pane == null) return null;
    return '$session:$window.$pane';
  }

  /// Set the loading state
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Set an error
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Clear the state
  void clear() {
    state = const TmuxState();
  }
}

/// Tmux provider
final tmuxProvider = NotifierProvider<TmuxNotifier, TmuxState>(() {
  return TmuxNotifier();
});
