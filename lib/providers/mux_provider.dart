import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mux/mux_backend.dart';
import '../services/mux/mux_models.dart';
import '../services/mux/mux_node.dart';

/// MuxBackend経由のマルチプレクサ状態
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

  /// アクティブセッションを取得
  MuxSession? get activeSession {
    if (activeSessionName == null) return null;
    try {
      return sessions.firstWhere((s) => s.name == activeSessionName);
    } catch (e) {
      return null;
    }
  }

  /// アクティブウィンドウを取得
  MuxWindow? get activeWindow {
    final session = activeSession;
    if (session == null || activeWindowIndex == null) return null;
    try {
      return session.windows.firstWhere((w) => w.index == activeWindowIndex);
    } catch (e) {
      return null;
    }
  }

  /// アクティブペインを取得
  MuxPane? get activePane {
    final window = activeWindow;
    if (window == null || activePaneId == null) return null;
    try {
      return window.panes.firstWhere((p) => p.id == activePaneId);
    } catch (e) {
      return null;
    }
  }

  /// 現在のバックエンドを取得
  MuxBackend? get currentBackend => currentNode?.backend;
}

/// MuxBackendを使用したマルチプレクサ状態管理
class MuxNotifier extends Notifier<MuxState> {
  @override
  MuxState build() => const MuxState();

  /// ルートノードを設定
  void setRootNode(MuxNode node) {
    developer.log('setRootNode: ${node.label}', name: 'MuxProvider');
    state = state.copyWith(rootNode: node, currentNode: node);
  }

  /// 現在のノードを設定
  void setCurrentNode(MuxNode node) {
    developer.log('setCurrentNode: ${node.label}', name: 'MuxProvider');
    state = state.copyWith(currentNode: node);
  }

  /// セッション一覧をリフレッシュ
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

  /// アクティブセッションを設定
  void setActiveSession(String sessionName) {
    developer.log('setActiveSession: $sessionName', name: 'MuxProvider');
    state = state.copyWith(
      activeSessionName: sessionName,
      clearActiveWindowIndex: true,
      clearActivePaneId: true,
    );
  }

  /// アクティブウィンドウを設定
  void setActiveWindow(int windowIndex) {
    developer.log('setActiveWindow: $windowIndex', name: 'MuxProvider');
    state = state.copyWith(
      activeWindowIndex: windowIndex,
      clearActivePaneId: true,
    );
  }

  /// アクティブペインを設定
  void setActivePane(String paneId) {
    developer.log('setActivePane: $paneId', name: 'MuxProvider');
    state = state.copyWith(activePaneId: paneId);
  }

  /// 子ノードへナビゲート
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

  /// 親ノードへナビゲート
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

  /// パンくずリストのパスを取得
  List<MuxNode> get breadcrumbPath {
    return state.currentNode?.breadcrumbPath() ?? [];
  }

  /// 状態をクリア
  void clear() {
    developer.log('clear()', name: 'MuxProvider');
    state = const MuxState();
  }
}

/// MuxBackend状態プロバイダー
final muxProvider = NotifierProvider<MuxNotifier, MuxState>(() {
  return MuxNotifier();
});
