import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mux/mux_backend.dart';
import '../services/mux/mux_models.dart';
import '../services/mux/mux_node.dart';

/// Multiplexer state via MuxBackend
class MuxState {
  final List<MuxSession> sessions;
  final String? activeSessionName;
  final int? activeWindowIndex;
  final String? activePaneId;
  final bool isLoading;
  final String? error;
  final MuxNode? rootNode;
  final MuxNode? currentNode;

  const MuxState({
    this.sessions = const [],
    this.activeSessionName,
    this.activeWindowIndex,
    this.activePaneId,
    this.isLoading = false,
    this.error,
    this.rootNode,
    this.currentNode,
  });

  MuxState copyWith({
    List<MuxSession>? sessions,
    String? activeSessionName,
    int? activeWindowIndex,
    String? activePaneId,
    bool? isLoading,
    String? error,
    MuxNode? rootNode,
    MuxNode? currentNode,
    bool clearActiveSessionName = false,
    bool clearActiveWindowIndex = false,
    bool clearActivePaneId = false,
    bool clearError = false,
  }) {
    return MuxState(
      sessions: sessions ?? this.sessions,
      activeSessionName:
          clearActiveSessionName ? null : (activeSessionName ?? this.activeSessionName),
      activeWindowIndex:
          clearActiveWindowIndex ? null : (activeWindowIndex ?? this.activeWindowIndex),
      activePaneId: clearActivePaneId ? null : (activePaneId ?? this.activePaneId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      rootNode: rootNode ?? this.rootNode,
      currentNode: currentNode ?? this.currentNode,
    );
  }

  /// Get the active session
  MuxSession? get activeSession {
    if (activeSessionName == null) return null;
    try {
      return sessions.firstWhere((s) => s.name == activeSessionName);
    } catch (e) {
      return null;
    }
  }

  /// Get the active window
  MuxWindow? get activeWindow {
    final session = activeSession;
    if (session == null || activeWindowIndex == null) return null;
    try {
      return session.windows.firstWhere((w) => w.index == activeWindowIndex);
    } catch (e) {
      return null;
    }
  }

  /// Get the active pane
  MuxPane? get activePane {
    final window = activeWindow;
    if (window == null || activePaneId == null) return null;
    try {
      return window.panes.firstWhere((p) => p.id == activePaneId);
    } catch (e) {
      return null;
    }
  }

  /// Get the current backend
  MuxBackend? get currentBackend => currentNode?.backend;
}

/// Multiplexer state management using MuxBackend
class MuxNotifier extends Notifier<MuxState> {
  @override
  MuxState build() => const MuxState();

  /// Set the root node
  void setRootNode(MuxNode node) {
    developer.log('setRootNode: ${node.label}', name: 'MuxProvider');
    state = state.copyWith(rootNode: node, currentNode: node);
  }

  /// Set the current node
  void setCurrentNode(MuxNode node) {
    developer.log('setCurrentNode: ${node.label}', name: 'MuxProvider');
    state = state.copyWith(currentNode: node);
  }

  /// Refresh the session list
  Future<void> refreshSessions() async {
    final backend = state.currentNode?.backend;
    if (backend == null) {
      developer.log('refreshSessions: no backend available', name: 'MuxProvider');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sessions = await backend.listSessions();
      developer.log('refreshSessions: found ${sessions.length} sessions',
          name: 'MuxProvider');
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (e, stackTrace) {
      developer.log('refreshSessions error: $e',
          name: 'MuxProvider', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set the active session
  void setActiveSession(String sessionName) {
    developer.log('setActiveSession: $sessionName', name: 'MuxProvider');
    state = state.copyWith(
      activeSessionName: sessionName,
      clearActiveWindowIndex: true,
      clearActivePaneId: true,
    );
  }

  /// Set the active window
  void setActiveWindow(int windowIndex) {
    developer.log('setActiveWindow: $windowIndex', name: 'MuxProvider');
    state = state.copyWith(
      activeWindowIndex: windowIndex,
      clearActivePaneId: true,
    );
  }

  /// Set the active pane
  void setActivePane(String paneId) {
    developer.log('setActivePane: $paneId', name: 'MuxProvider');
    state = state.copyWith(activePaneId: paneId);
  }

  /// Navigate to a child node
  void navigateToChild(MuxNode child) {
    developer.log('navigateToChild: ${child.label}', name: 'MuxProvider');
    state = state.copyWith(
      currentNode: child,
      sessions: const [],
      clearActiveSessionName: true,
      clearActiveWindowIndex: true,
      clearActivePaneId: true,
    );
  }

  /// Navigate to the parent node
  void navigateToParent() {
    final parent = state.currentNode?.parent;
    if (parent != null) {
      developer.log('navigateToParent: ${parent.label}', name: 'MuxProvider');
      state = state.copyWith(
        currentNode: parent,
        sessions: const [],
        clearActiveSessionName: true,
        clearActiveWindowIndex: true,
        clearActivePaneId: true,
      );
    }
  }

  /// Get the breadcrumb path
  List<MuxNode> get breadcrumbPath {
    return state.currentNode?.breadcrumbPath() ?? [];
  }

  /// Clear the state
  void clear() {
    developer.log('clear()', name: 'MuxProvider');
    state = const MuxState();
  }
}

/// MuxBackend state provider
final muxProvider = NotifierProvider<MuxNotifier, MuxState>(() {
  return MuxNotifier();
});
