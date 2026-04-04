import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';

import '../../providers/active_session_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/mux_provider.dart';
import '../../providers/tmux_provider.dart';
import '../../services/keychain/secure_storage.dart';
import '../../services/mux/mux_backend.dart';
import '../../services/mux/mux_detector.dart';
import '../../services/mux/mux_node.dart';
import '../../services/mux/mux_pty_session.dart';
import '../../services/mux/mux_types.dart';
import '../../services/mux/psmux_backend.dart';
import '../../services/mux/ssh_executor.dart';
import '../../services/mux/tmux_backend.dart';
import '../../services/network/network_monitor.dart';
import '../../services/ssh/input_queue.dart';
import '../../services/ssh/ssh_client.dart' show SshConnectOptions;
import '../../services/tmux/pane_navigator.dart';
import '../../services/tmux/tmux_commands.dart';
import '../../services/tmux/tmux_parser.dart';
import '../../theme/design_colors.dart';
import '../../widgets/special_keys_bar.dart';
import '../settings/settings_screen.dart';

/// ターミナル画面（xterm.dart TerminalView使用）
class TerminalScreen extends ConsumerStatefulWidget {
  final String connectionId;
  final String? sessionName;

  /// 復元用: 最後に開いていたウィンドウインデックス
  final int? lastWindowIndex;

  /// 復元用: 最後に開いていたペインID
  final String? lastPaneId;

  /// ディープリンク用: ウィンドウ名で指定（インデックスではなく名前で検索）
  final String? deepLinkWindowName;

  /// ディープリンク用: ペインインデックス
  final int? deepLinkPaneIndex;

  const TerminalScreen({
    super.key,
    required this.connectionId,
    this.sessionName,
    this.lastWindowIndex,
    this.lastPaneId,
    this.deepLinkWindowName,
    this.deepLinkPaneIndex,
  });

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver {
  final _secureStorage = SecureStorageService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // xterm.dart Terminal instance
  late final Terminal _terminal;

  // PTY session from MuxBackend.attachPty()
  MuxPtySession? _ptySession;
  StreamSubscription<List<int>>? _ptySubscription;

  // 接続状態（ローカルで管理）
  bool _isConnecting = false;
  String? _connectionError;
  SshState _sshState = const SshState();

  // ツリーリフレッシュタイマー
  Timer? _treeRefreshTimer;
  bool _isDisposed = false;

  // ズームスケール
  double _zoomScale = 1.0;

  // EnterCommand入力内容保持（ボトムシートを閉じても保持）
  String _savedCommandInput = '';

  // 入力キュー（切断中の入力を保持）
  final _inputQueue = InputQueue();

  // directInput設定のローカルキャッシュ（ref.watch回避）
  bool _directInputEnabled = true;

  // 検出されたMuxバックエンド名（'tmux' or 'psmux'）
  String _muxBackendName = 'tmux';

  // Riverpodリスナー
  ProviderSubscription<SshState>? _sshSubscription;
  ProviderSubscription<TmuxState>? _tmuxSubscription;
  ProviderSubscription<AppSettings>? _settingsSubscription;
  ProviderSubscription<AsyncValue<NetworkStatus>>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _terminal = Terminal(maxLines: 10000);

    _terminal.onOutput = (String data) {
      _ptySession?.write(Uint8List.fromList(utf8.encode(data)));
    };

    _terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
      _ptySession?.resize(width, height);
    };

    // 次フレームでリスナーを設定（ref使用のため）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupListeners();
      _connectAndSetup();
      _applyKeepScreenOn();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        WakelockPlus.disable();
        break;
      case AppLifecycleState.resumed:
        _applyKeepScreenOn();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Keep screen on設定を適用
  void _applyKeepScreenOn() {
    final settings = ref.read(settingsProvider);
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  /// Providerのリスナーを設定
  void _setupListeners() {
    // SSH状態の変化を監視
    _sshSubscription = ref.listenManual<SshState>(
      sshProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        setState(() {
          _sshState = next;
        });
      },
      fireImmediately: true,
    );

    // Tmux状態の変化を監視
    _tmuxSubscription = ref.listenManual<TmuxState>(
      tmuxProvider,
      (previous, next) {
        // Consumer widgets が直接 tmuxProvider を watch しているため、
        // 親の setState() は不要
      },
      fireImmediately: true,
    );

    // 設定の変化を監視（Keep screen on / directInput用）
    _settingsSubscription = ref.listenManual<AppSettings>(
      settingsProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        if (previous?.keepScreenOn != next.keepScreenOn) {
          _applyKeepScreenOn();
        }
        if (previous?.directInputEnabled != next.directInputEnabled) {
          setState(() {
            _directInputEnabled = next.directInputEnabled;
          });
        }
      },
      fireImmediately: false,
    );

    // 初期値を明示的に設定
    _directInputEnabled = ref.read(settingsProvider).directInputEnabled;

    // ネットワーク状態の変化を監視（実際の接続状態変化時のみ更新）
    _networkSubscription = ref.listenManual<AsyncValue<NetworkStatus>>(
      networkStatusProvider,
      (previous, next) {
        if (!mounted || _isDisposed) return;
        final prevStatus = previous?.value;
        final nextStatus = next.value;
        if (prevStatus != nextStatus) {
          setState(() {});
        }
      },
      fireImmediately: true,
    );

    // 再接続成功時の処理を設定
    final sshNotifier = ref.read(sshProvider.notifier);
    sshNotifier.onReconnectSuccess = _onReconnectSuccess;
  }

  /// 再接続成功時の処理
  Future<void> _onReconnectSuccess() async {
    if (!mounted || _isDisposed) return;

    // Muxバックエンドを再検出してPTYを再接続
    final connection = ref.read(connectionsProvider.notifier).getById(widget.connectionId);
    if (connection != null) {
      await _detectAndSetupMuxBackend(connection);
    }

    // PTYを再接続
    final backend = ref.read(muxProvider).currentBackend;
    if (backend != null) {
      await _attachPty(backend);
    }

    // セッションツリーを再取得
    _startTreeRefresh();

    // キューされた入力を送信
    await _flushInputQueue();

    // UIを更新
    if (mounted) setState(() {});
  }

  /// キューされた入力を送信
  Future<void> _flushInputQueue() async {
    if (_inputQueue.isEmpty) return;

    final queuedInput = _inputQueue.flush();
    if (queuedInput.isNotEmpty) {
      _writeToPty(queuedInput);
    }
  }

  /// TmuxCommandsの出力をMuxバックエンドに応じて変換
  ///
  /// psmuxの場合、先頭の "tmux " を "psmux " に置換する。
  String _resolveMuxCmd(String cmd) {
    if (_muxBackendName == 'psmux') {
      return cmd.replaceFirst('tmux ', 'psmux ');
    }
    return cmd;
  }

  /// Muxバックエンドを検出してMuxProviderにセットアップ
  Future<void> _detectAndSetupMuxBackend(Connection connection) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null) return;

    final executor = SshExecutor(sshClient);

    debugPrint('[Terminal] Detecting mux backend (connection.muxType=${connection.muxType})');

    // バックエンド種別を決定
    MuxType detectedType;
    if (connection.muxType == 'psmux') {
      detectedType = MuxType.psmux;
      debugPrint('[Terminal] Using explicit psmux backend');
    } else if (connection.muxType == 'tmux') {
      detectedType = MuxType.tmux;
      debugPrint('[Terminal] Using explicit tmux backend');
    } else {
      // auto: MuxDetectorで検出
      debugPrint('[Terminal] Auto-detecting backend...');
      final detector = MuxDetector(executor);
      detectedType = await detector.detect();
      debugPrint('[Terminal] Auto-detect result: $detectedType');
    }

    _muxBackendName = detectedType == MuxType.psmux ? 'psmux' : 'tmux';
    debugPrint('[Terminal] Detected mux backend: $_muxBackendName');

    // MuxBackendを作成
    final backend = detectedType == MuxType.psmux
        ? PsmuxBackend(executor)
        : TmuxBackend(executor);

    // MuxNodeツリーを構築してMuxProviderにセット
    final rootNode = MuxNode(
      backend: backend,
      executor: executor,
    );
    ref.read(muxProvider.notifier).setRootNode(rootNode);
  }

  // ---------------------------------------------------------------------------
  // PTY lifecycle
  // ---------------------------------------------------------------------------

  /// PTYセッションをアタッチ
  Future<void> _attachPty(MuxBackend backend) async {
    await _closePty();

    final sessionName = ref.read(tmuxProvider).activeSessionName;
    if (sessionName == null) return;

    _ptySession = await backend.attachPty(sessionName);

    _ptySubscription = _ptySession!.stdout.listen(
      (data) {
        if (!_isDisposed) {
          _terminal.write(String.fromCharCodes(data));
        }
      },
      onError: (error) {
        debugPrint('PTY stream error: $error');
        if (!_isDisposed) {
          _attemptReconnect();
        }
      },
      onDone: () {
        debugPrint('PTY stream closed');
      },
    );
  }

  /// PTYセッションをクローズ
  Future<void> _closePty() async {
    await _ptySubscription?.cancel();
    _ptySubscription = null;
    if (_ptySession != null) {
      try {
        await _ptySession!.close();
      } catch (_) {
        // Ignore close errors
      }
    }
    _ptySession = null;
  }

  /// PTYにデータを書き込む
  void _writeToPty(String data) {
    if (_ptySession == null) {
      _inputQueue.enqueue(data);
      return;
    }
    _ptySession!.write(Uint8List.fromList(utf8.encode(data)));
  }

  // ---------------------------------------------------------------------------
  // Connection setup
  // ---------------------------------------------------------------------------

  /// SSH接続してtmuxセッションをセットアップ
  Future<void> _connectAndSetup() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // 1. 接続情報を取得
      final connection = ref.read(connectionsProvider.notifier).getById(widget.connectionId);
      if (connection == null) {
        throw Exception('Connection not found');
      }

      // 2. 認証情報を取得
      final options = await _getAuthOptions(connection);
      if (!mounted || _isDisposed) {
        return;
      }

      // 3. SSH接続（シェルは起動しない - execのみ使用）
      final sshNotifier = ref.read(sshProvider.notifier);
      await sshNotifier.connectWithoutShell(connection, options);
      if (!mounted || _isDisposed) {
        return;
      }

      // 3.5. Muxバックエンドを検出してセットアップ
      await _detectAndSetupMuxBackend(connection);
      if (!mounted || _isDisposed) {
        return;
      }

      // 4. セッションツリー全体を取得
      await _refreshSessionTree();
      if (!mounted || _isDisposed) {
        return;
      }

      final tmuxState = ref.read(tmuxProvider);
      final sessions = tmuxState.sessions;

      // 5. セッションを選択または新規作成
      String sessionName;
      if (widget.sessionName != null) {
        // セッション名が指定されている場合
        final existingIndex = sessions.indexWhere(
          (s) => s.name == widget.sessionName,
        );
        if (existingIndex >= 0) {
          // 既存セッションに接続
          sessionName = sessions[existingIndex].name;
        } else {
          // 新規セッション作成
          final sshClient = ref.read(sshProvider.notifier).client;
          await sshClient?.exec(_resolveMuxCmd(TmuxCommands.newSession(
            name: widget.sessionName!,
            detached: true,
          )));
          if (!mounted || _isDisposed) return;
          await _refreshSessionTree();
          if (!mounted || _isDisposed) return;
          sessionName = widget.sessionName!;
        }
      } else if (sessions.isNotEmpty) {
        // セッション名が指定されていない場合は最初のセッションに接続
        sessionName = sessions.first.name;
      } else {
        // セッションがない場合は自動生成名で新規作成
        final sshClient = ref.read(sshProvider.notifier).client;
        sessionName = 'muxpod-${DateTime.now().millisecondsSinceEpoch}';
        await sshClient?.exec(_resolveMuxCmd(TmuxCommands.newSession(name: sessionName, detached: true)));
        if (!mounted || _isDisposed) return;
        await _refreshSessionTree();
        if (!mounted || _isDisposed) return;
      }

      // 6. アクティブセッション/ウィンドウ/ペインを設定
      ref.read(tmuxProvider.notifier).setActiveSession(sessionName);

      // 6.0 選択セッションのwindows/panesが空の場合、個別に取得
      {
        final activeSession = ref.read(tmuxProvider).activeSession;
        if (activeSession != null && activeSession.windows.isEmpty) {
          debugPrint('[Terminal] Active session "${activeSession.name}" has no windows, fetching individually');
          await _fetchWindowsAndPanesForSession(sessionName);
          if (!mounted || _isDisposed) return;
          // 再度アクティブセッションを設定（windows/panes更新済み）
          ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
        }
      }

      // 6.1 ディープリンクまたは保存されたウィンドウ/ペイン位置を復元
      if (widget.deepLinkWindowName != null) {
        // ディープリンク: ウィンドウ名で検索
        final tmuxState = ref.read(tmuxProvider);
        final session = tmuxState.activeSession;
        if (session != null) {
          final targetName = widget.deepLinkWindowName!;
          // ウィンドウ名で検索（"index:name" 形式の名前部分にも対応）
          TmuxWindow? window;
          for (final w in session.windows) {
            if (w.name == targetName || w.name.endsWith(':$targetName')) {
              window = w;
              break;
            }
          }
          if (window != null) {
            ref.read(tmuxProvider.notifier).setActiveWindow(window.index);

            // ペインインデックスが指定されている場合
            if (widget.deepLinkPaneIndex != null && widget.deepLinkPaneIndex! < window.panes.length) {
              final pane = window.panes[widget.deepLinkPaneIndex!];
              ref.read(tmuxProvider.notifier).setActivePane(pane.id);
            }
          }
        }
      } else if (widget.lastWindowIndex != null) {
        // 通常の復元: インデックスで検索
        final tmuxState = ref.read(tmuxProvider);
        final session = tmuxState.activeSession;
        if (session != null) {
          // 指定されたウィンドウが存在するか確認
          final window = session.windows.firstWhere(
            (w) => w.index == widget.lastWindowIndex,
            orElse: () => session.windows.first,
          );
          ref.read(tmuxProvider.notifier).setActiveWindow(window.index);

          // ペインIDが指定されていて存在する場合は復元
          if (widget.lastPaneId != null) {
            final pane = window.panes.firstWhere(
              (p) => p.id == widget.lastPaneId,
              orElse: () => window.panes.first,
            );
            ref.read(tmuxProvider.notifier).setActivePane(pane.id);
          }
        }
      }

      // 7. PTYをアタッチ（xterm.dartのTerminalに接続）
      final backend = ref.read(muxProvider).currentBackend;
      if (backend != null) {
        await _attachPty(backend);
        if (!mounted || _isDisposed) return;
      }

      // 8. 10秒ごとにセッションツリーを更新
      _startTreeRefresh();

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });
      _showErrorSnackBar(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Session tree management
  // ---------------------------------------------------------------------------

  /// セッションツリー全体を取得して更新
  Future<void> _refreshSessionTree() async {
    if (_isDisposed) {
      return;
    }
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      return;
    }

    try {
      final cmd = _resolveMuxCmd(TmuxCommands.listAllPanes());
      debugPrint('[Terminal] refreshSessionTree cmd: ${cmd.substring(0, cmd.length.clamp(0, 80))}...');
      final output = await sshClient.exec(cmd);
      debugPrint('[Terminal] refreshSessionTree output (${output.length} chars): ${output.substring(0, output.length.clamp(0, 200))}');
      if (!mounted || _isDisposed) return;

      // -Fフォーマット出力を試行（|||区切りがあるか確認）
      if (output.contains(TmuxCommands.delimiter)) {
        ref.read(tmuxProvider.notifier).parseAndUpdateFullTree(output);

        // psmux: list-panes -a が一部セッションしか返さない場合、
        // list-sessions で補完して全セッション名を取得する
        final treeState = ref.read(tmuxProvider);
        if (treeState.sessions.isNotEmpty) {
          final sessionsCmd = _resolveMuxCmd(TmuxCommands.listSessions());
          final sessionsOutput = await sshClient.exec(sessionsCmd);
          if (!mounted || _isDisposed) return;
          final allSessions = TmuxParser.parseSessions(sessionsOutput);
          // ツリーに含まれないセッションを追加（windows空で追加）
          final treeNames = treeState.sessions.map((s) => s.name).toSet();
          final missing = allSessions.where((s) => !treeNames.contains(s.name));
          if (missing.isNotEmpty) {
            final merged = [...treeState.sessions, ...missing];
            ref.read(tmuxProvider.notifier).updateSessions(merged);
          }
        }
      } else {
        // -F非対応: list-sessionsのデフォルト出力をフォールバックパース
        debugPrint('[Terminal] No ||| delimiters found, falling back to list-sessions');
        final sessionsCmd = _resolveMuxCmd(TmuxCommands.listSessions());
        final sessionsOutput = await sshClient.exec(sessionsCmd);
        if (!mounted || _isDisposed) return;
        ref.read(tmuxProvider.notifier).parseAndUpdateSessions(sessionsOutput);

        // デフォルト出力からはwindows/panes情報がないため、
        // 各セッションのwindowsとpanesを個別に取得
        await _fetchWindowsAndPanesForSessions();
      }
    } catch (e) {
      debugPrint('[Terminal] refreshSessionTree error: $e');
    }
  }

  /// 単一セッションのwindows/panesを個別フェッチしてtmuxProviderを更新
  Future<void> _fetchWindowsAndPanesForSession(String sessionName) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    try {
      // ウィンドウ一覧
      final winCmd = _resolveMuxCmd(TmuxCommands.listWindows(sessionName));
      final winOutput = await sshClient.exec(winCmd);
      var windows = TmuxParser.parseWindows(winOutput);
      if (windows.isEmpty && winOutput.trim().isNotEmpty) {
        windows = TmuxParser.parseWindowsDefault(winOutput);
      }

      // 各ウィンドウのペイン一覧
      final updatedWindows = <TmuxWindow>[];
      for (final window in windows) {
        try {
          final paneCmd = _resolveMuxCmd(TmuxCommands.listPanes(sessionName, window.index));
          final paneOutput = await sshClient.exec(paneCmd);
          var panes = TmuxParser.parsePanes(paneOutput);
          if (panes.isEmpty && paneOutput.trim().isNotEmpty) {
            panes = TmuxParser.parsePanesDefault(paneOutput);
          }
          updatedWindows.add(window.copyWith(panes: panes, paneCount: panes.length));
        } catch (_) {
          updatedWindows.add(window);
        }
      }

      if (!mounted || _isDisposed) return;

      // tmuxProviderのセッションリストを更新
      final currentSessions = ref.read(tmuxProvider).sessions;
      final updatedSessions = currentSessions.map((s) {
        if (s.name == sessionName) {
          return s.copyWith(windows: updatedWindows, windowCount: updatedWindows.length);
        }
        return s;
      }).toList();

      // セッションがまだリストにない場合は追加
      if (!updatedSessions.any((s) => s.name == sessionName)) {
        updatedSessions.add(TmuxSession(
          name: sessionName,
          windows: updatedWindows,
          windowCount: updatedWindows.length,
        ));
      }

      ref.read(tmuxProvider.notifier).updateSessions(updatedSessions);
    } catch (e) {
      debugPrint('[Terminal] _fetchWindowsAndPanesForSession error: $e');
    }
  }

  /// セッションごとにwindowsとpanesを個別フェッチ（-F非対応時のフォールバック）
  Future<void> _fetchWindowsAndPanesForSessions() async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    final sessions = ref.read(tmuxProvider).sessions;
    final updatedSessions = <TmuxSession>[];

    for (final session in sessions) {
      try {
        // ウィンドウ一覧を取得
        final winCmd = _resolveMuxCmd(TmuxCommands.listWindows(session.name));
        final winOutput = await sshClient.exec(winCmd);
        var windows = TmuxParser.parseWindows(winOutput);

        // -Fフォーマットが効かない場合、デフォルトフォーマットをパース
        if (windows.isEmpty && winOutput.trim().isNotEmpty) {
          windows = TmuxParser.parseWindowsDefault(winOutput);
        }

        // 各ウィンドウのペイン一覧を取得
        final updatedWindows = <TmuxWindow>[];
        for (final window in windows) {
          try {
            final paneCmd = _resolveMuxCmd(TmuxCommands.listPanes(session.name, window.index));
            final paneOutput = await sshClient.exec(paneCmd);
            var panes = TmuxParser.parsePanes(paneOutput);

            if (panes.isEmpty && paneOutput.trim().isNotEmpty) {
              panes = TmuxParser.parsePanesDefault(paneOutput);
            }

            updatedWindows.add(window.copyWith(panes: panes, paneCount: panes.length));
          } catch (_) {
            updatedWindows.add(window);
          }
        }

        updatedSessions.add(session.copyWith(
          windows: updatedWindows,
          windowCount: updatedWindows.length,
        ));
      } catch (_) {
        updatedSessions.add(session);
      }
    }

    if (!mounted || _isDisposed) return;
    ref.read(tmuxProvider.notifier).updateSessions(updatedSessions);
  }

  /// 10秒ごとにセッションツリーを更新
  void _startTreeRefresh() {
    _treeRefreshTimer?.cancel();
    _treeRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _refreshSessionTree();
      },
    );
  }

  /// 自動再接続を試みる
  Future<void> _attemptReconnect() async {
    if (_isDisposed) return;

    final sshNotifier = ref.read(sshProvider.notifier);
    final success = await sshNotifier.reconnect();

    if (!mounted || _isDisposed) return;

    if (!success) {
      // 再接続失敗時は再試行（最大回数に達するまで）
      final currentState = ref.read(sshProvider);
      if (currentState.reconnectAttempt < 5) {
        // 次のサイクルで再試行される
      }
    }
  }

  /// 認証オプションを取得
  Future<SshConnectOptions> _getAuthOptions(Connection connection) async {
    if (connection.authMethod == 'key' && connection.keyId != null) {
      final privateKey = await _secureStorage.getPrivateKey(connection.keyId!);
      final passphrase = await _secureStorage.getPassphrase(connection.keyId!);
      return SshConnectOptions(privateKey: privateKey, passphrase: passphrase);
    } else {
      final password = await _secureStorage.getPassword(connection.id);
      return SshConnectOptions(password: password);
    }
  }

  /// エラーSnackBar表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _connectAndSetup,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation (session / window / pane)
  // ---------------------------------------------------------------------------

  /// セッションを選択
  Future<void> _selectSession(String sessionName) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null) return;

    // tmux_providerでアクティブセッションを更新
    ref.read(tmuxProvider.notifier).setActiveSession(sessionName);

    // switch-clientでセッションを切り替え（PTY経由でtmuxが自動的にリドローする）
    try {
      await sshClient.execPersistent(
        _resolveMuxCmd('tmux switch-client -t $sessionName'),
      );
    } catch (e) {
      debugPrint('[Terminal] Failed to switch session: $e');
    }
  }

  /// ウィンドウを選択
  Future<void> _selectWindow(String sessionName, int windowIndex) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    // セッションが異なる場合はセッションも切り替え
    final currentSession = ref.read(tmuxProvider).activeSessionName;
    if (currentSession != sessionName) {
      ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
    }

    try {
      // tmux select-windowを実行
      await sshClient.exec(_resolveMuxCmd(TmuxCommands.selectWindow(sessionName, windowIndex)));
    } catch (e) {
      // SSH接続が閉じている場合は無視
      debugPrint('[Terminal] Failed to select window: $e');
      return;
    }
    if (!mounted || _isDisposed) return;

    // tmux_providerでアクティブウィンドウを更新
    ref.read(tmuxProvider.notifier).setActiveWindow(windowIndex);
  }

  /// ペインを選択
  Future<void> _selectPane(String paneId) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) return;

    final oldPaneId = ref.read(tmuxProvider).activePaneId;

    try {
      // 前のペインにフォーカスアウトを送信
      if (oldPaneId != null && oldPaneId != paneId) {
        await sshClient.exec(_resolveMuxCmd(TmuxCommands.sendKeys(oldPaneId, '\x1b[O', literal: true)));
      }

      // tmux select-paneを実行
      await sshClient.exec(_resolveMuxCmd(TmuxCommands.selectPane(paneId)));

      // 新しいペインにフォーカスインを送信
      await sshClient.exec(_resolveMuxCmd(TmuxCommands.sendKeys(paneId, '\x1b[I', literal: true)));
    } catch (e) {
      // SSH接続が閉じている場合は無視
      debugPrint('[Terminal] Failed to select pane: $e');
      return;
    }
    if (!mounted || _isDisposed) return;

    // tmux_providerでアクティブペインを更新
    ref.read(tmuxProvider.notifier).setActivePane(paneId);

    // セッション情報を保存（復元用）
    final tmuxState = ref.read(tmuxProvider);
    final sessionName = tmuxState.activeSessionName;
    final windowIndex = tmuxState.activeWindowIndex;
    if (sessionName != null && windowIndex != null) {
      ref.read(activeSessionsProvider.notifier).updateLastPane(
            connectionId: widget.connectionId,
            sessionName: sessionName,
            windowIndex: windowIndex,
            paneId: paneId,
          );
    }
  }

  /// 2本指スワイプによるペイン切り替え
  ///
  /// TerminalViewは内部でジェスチャーを処理するため、現在は直接ワイヤリングされていない。
  /// 将来的にTerminalViewのカスタムジェスチャーレイヤーを追加する際に使用する。
  // ignore: unused_element
  void _handleTwoFingerSwipe(SwipeDirection direction) {
    final tmuxState = ref.read(tmuxProvider);
    final window = tmuxState.activeWindow;
    final activePane = tmuxState.activePane;
    if (window == null || activePane == null) return;

    // 設定に応じてスワイプ方向を反転
    final settings = ref.read(settingsProvider);
    final actualDirection = settings.invertPaneNavigation
        ? direction.inverted
        : direction;

    final targetPane = PaneNavigator.findAdjacentPane(
      panes: window.panes,
      current: activePane,
      direction: actualDirection,
    );

    if (targetPane != null) {
      _selectPane(targetPane.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void deactivate() {
    // ref.readはdeactivateまでは安全（disposeでは_elementsから外れている）
    final sshNotifier = ref.read(sshProvider.notifier);
    sshNotifier.onReconnectSuccess = null;
    sshNotifier.onDisconnectDetected = null;

    // popUntil等で_disconnect()を経由せずにpopされた場合もSSHを切断
    if (sshNotifier.checkConnection()) {
      sshNotifier.disconnect();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    // まず_isDisposedをセットして非同期処理を停止
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // WakeLockを無効化
    WakelockPlus.disable();
    // PTYをクローズ
    _closePty();
    // Riverpodサブスクリプションをキャンセル
    _sshSubscription?.close();
    _sshSubscription = null;
    _tmuxSubscription?.close();
    _tmuxSubscription = null;
    _settingsSubscription?.close();
    _settingsSubscription = null;
    _networkSubscription?.close();
    _networkSubscription = null;
    // タイマーを停止
    _treeRefreshTimer?.cancel();
    _treeRefreshTimer = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sshState = _sshState;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // ブレッドクラム: ConsumerでtmuxProviderを直接watch
              Consumer(
                builder: (context, ref, _) {
                  final tmuxState = ref.watch(tmuxProvider);
                  return _buildBreadcrumbHeader(tmuxState);
                },
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final settings = ref.watch(settingsProvider);
                    return GestureDetector(
                      // 2本指スワイプ検出用の外側GestureDetector
                      // TerminalViewは内部でスクロール等を処理するので、
                      // ここではonTwoFingerSwipeを検出する
                      child: Stack(
                        children: [
                          // TerminalView（xterm.dart）
                          TerminalView(
                            _terminal,
                            textStyle: TerminalStyle(
                              fontSize: settings.fontSize * _zoomScale,
                              fontFamily: settings.fontFamily,
                            ),
                            autofocus: true,
                          ),
                          // Pane indicator: ConsumerでtmuxProviderを直接watch
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final tmuxState = ref.watch(tmuxProvider);
                                return _buildPaneIndicator(tmuxState);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SpecialKeysBar(
                onKeyPressed: (String key) {
                  _writeToPty(key);
                },
                onSpecialKeyPressed: (String escapeSequence) {
                  _writeToPty(escapeSequence);
                },
                onInputTap: _showInputDialog,
                directInputEnabled: _directInputEnabled,
                onDirectInputToggle: () {
                  ref.read(settingsProvider.notifier).toggleDirectInput();
                },
              ),
            ],
          ),
          // ローディングオーバーレイ
          if (_isConnecting || sshState.isConnecting)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // エラーオーバーレイ
          if (_connectionError != null || sshState.hasError)
            _buildErrorOverlay(sshState.error ?? _connectionError),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input dialog
  // ---------------------------------------------------------------------------

  void _showInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _InputDialogContent(
        initialValue: _savedCommandInput,
        onValueChanged: (value) {
          // 入力内容をリアルタイムで保存
          _savedCommandInput = value;
        },
        onSend: (value) async {
          _writeToPty('$value\n');
          // 送信成功したら入力内容をクリア
          _savedCommandInput = '';
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Terminal menu
  // ---------------------------------------------------------------------------

  /// ターミナルメニューを表示
  void _showTerminalMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuBgColor = isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.white38 : Colors.black38;
    final inactiveIconColor = isDark ? Colors.white60 : Colors.black45;

    showModalBottomSheet(
      context: context,
      backgroundColor: menuBgColor,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: DesignColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Terminal Options',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // ズームリセット
              ListTile(
                leading: Icon(
                  Icons.zoom_out_map,
                  color: _zoomScale != 1.0 ? DesignColors.warning : inactiveIconColor,
                ),
                title: Text(
                  'Reset Zoom',
                  style: TextStyle(
                    color: _zoomScale != 1.0 ? textColor : mutedTextColor,
                  ),
                ),
                subtitle: Text(
                  _zoomScale != 1.0
                      ? 'Current: ${(_zoomScale * 100).toStringAsFixed(0)}%'
                      : 'Pinch to zoom in/out',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                enabled: _zoomScale != 1.0,
                onTap: _zoomScale != 1.0
                    ? () {
                        setState(() {
                          _zoomScale = 1.0;
                        });
                        Navigator.pop(context);
                      }
                    : null,
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // 設定画面へ
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: inactiveIconColor,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  'Font, theme, and other options',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF2A2B36) : Colors.grey.shade300),
              // 切断ボタン
              ListTile(
                leading: Icon(
                  Icons.power_settings_new,
                  color: DesignColors.error,
                ),
                title: Text(
                  'Disconnect',
                  style: TextStyle(
                    color: DesignColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Close SSH connection',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDisconnectConfirmation();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 切断確認ダイアログを表示
  void _showDisconnectConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
          title: Text(
            'Disconnect?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Are you sure you want to disconnect from the server?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // ダイアログを閉じる
                await _disconnect();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  /// SSH接続を切断して前の画面に戻る
  Future<void> _disconnect() async {
    // PTYをクローズ
    await _closePty();

    // タイマーを停止
    _treeRefreshTimer?.cancel();

    // SSH切断
    await ref.read(sshProvider.notifier).disconnect();

    // 前の画面に戻る
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Error overlay
  // ---------------------------------------------------------------------------

  Widget _buildErrorOverlay(String? error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final queuedCount = _inputQueue.length;
    final isWaitingForNetwork = _sshState.isWaitingForNetwork;

    return Container(
      color: isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWaitingForNetwork ? Icons.signal_wifi_off : Icons.error_outline,
              color: isWaitingForNetwork ? DesignColors.warning : colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isWaitingForNetwork
                  ? 'Waiting for network...'
                  : (error ?? 'Connection error'),
              style: TextStyle(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),

            // キューイング状態
            if (queuedCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard,
                      size: 16,
                      color: DesignColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$queuedCount chars queued',
                      style: TextStyle(
                        color: DesignColors.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _inputQueue.clear();
                        setState(() {});
                      },
                      child: Icon(
                        Icons.clear,
                        size: 16,
                        color: DesignColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref.read(sshProvider.notifier).reconnectNow();
                  },
                  child: const Text('Retry Now'),
                ),
                if (_sshState.isReconnecting) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Breadcrumb header
  // ---------------------------------------------------------------------------

  Widget _buildBreadcrumbHeader(TmuxState tmuxState) {
    final currentSession = tmuxState.activeSessionName ?? '';
    final activeWindow = tmuxState.activeWindow;
    final currentWindow = activeWindow?.name ?? '';
    final activePane = tmuxState.activePane;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(color: colorScheme.outline, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // Breadcrumb navigation
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // セッション名（タップで切り替え）
                    _buildBreadcrumbItem(
                      currentSession,
                      icon: Icons.folder,
                      isActive: true,
                      onTap: () => _showSessionSelector(tmuxState),
                    ),
                    _buildBreadcrumbSeparator(),
                    // ウィンドウ名（タップで切り替え）
                    _buildBreadcrumbItem(
                      currentWindow,
                      icon: Icons.tab,
                      isSelected: true,
                      onTap: () => _showWindowSelector(tmuxState),
                    ),
                    // ペインがあれば表示
                    if (activePane != null) ...[
                      _buildBreadcrumbSeparator(),
                      _buildBreadcrumbItem(
                        'Pane ${activePane.index}',
                        icon: Icons.terminal,
                        isActive: false,
                        onTap: () => _showPaneSelector(tmuxState),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Zoom indicator
            if (_zoomScale != 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: DesignColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(_zoomScale * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: DesignColors.warning,
                  ),
                ),
              ),
            // Connection indicator (reconnect or connected)
            _buildConnectionIndicator(),
            // Settings button
            IconButton(
              onPressed: _showTerminalMenu,
              icon: Icon(
                Icons.settings,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// 接続状態インジケーター
  Widget _buildConnectionIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: _sshState.isReconnecting
          ? _buildReconnectingIndicator()
          : _buildConnectedIndicator(),
    );
  }

  /// 接続済みインジケーター
  Widget _buildConnectedIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: DesignColors.success.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          'PTY',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: DesignColors.success.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// 再接続中インジケーター
  Widget _buildReconnectingIndicator() {
    final attempt = _sshState.reconnectAttempt;
    final isWaitingForNetwork = _sshState.isWaitingForNetwork;
    final nextRetryAt = _sshState.nextRetryAt;
    final queuedCount = _inputQueue.length;

    // 次回リトライまでの秒数を計算
    String? countdownText;
    if (nextRetryAt != null && !isWaitingForNetwork) {
      final remaining = nextRetryAt.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        countdownText = '${remaining}s';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // スピナーまたは圏外アイコン
        if (isWaitingForNetwork)
          Icon(
            Icons.signal_wifi_off,
            size: 12,
            color: DesignColors.warning.withValues(alpha: 0.8),
          )
        else
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: DesignColors.warning.withValues(alpha: 0.8),
            ),
          ),
        const SizedBox(width: 6),

        // ステータステキスト
        Text(
          isWaitingForNetwork
              ? 'Offline'
              : 'Reconnecting${attempt > 1 ? ' ($attempt)' : ''}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: DesignColors.warning.withValues(alpha: 0.8),
          ),
        ),

        // カウントダウン
        if (countdownText != null) ...[
          const SizedBox(width: 4),
          Text(
            countdownText,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: DesignColors.textMuted,
            ),
          ),
        ],

        // キューイング状態
        if (queuedCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: DesignColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$queuedCount chars',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: DesignColors.primary,
              ),
            ),
          ),
        ],

        // 今すぐ再接続ボタン
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            ref.read(sshProvider.notifier).reconnectNow();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: DesignColors.warning.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: DesignColors.warning,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Session / Window / Pane selectors
  // ---------------------------------------------------------------------------

  void _showSessionSelector(TmuxState tmuxState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.folder, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Session',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tmuxState.sessions.length,
                    itemBuilder: (context, index) {
                      final session = tmuxState.sessions[index];
                      final isActive = session.name == tmuxState.activeSessionName;
                      return ListTile(
                        leading: Icon(
                          Icons.folder,
                          color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        title: Text(
                          session.name,
                          style: TextStyle(
                            color: isActive ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${session.windowCount} windows',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
                        ),
                        trailing: isActive
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _selectSession(session.name);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWindowSelector(TmuxState tmuxState) {
    final session = tmuxState.activeSession;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.tab, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Window',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: session.windows.length,
                    itemBuilder: (context, index) {
                      final window = session.windows[index];
                      final isActive = window.index == tmuxState.activeWindowIndex;
                      return ListTile(
                        leading: Icon(
                          Icons.tab,
                          color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        title: Text(
                          '${window.index}: ${window.name}',
                          style: TextStyle(
                            color: isActive ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${window.paneCount} panes',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
                        ),
                        trailing: isActive
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _selectWindow(session.name, window.index);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ペインを分割
  Future<void> _splitPane(String paneId, SplitDirection direction) async {
    final sshClient = ref.read(sshProvider.notifier).client;
    if (sshClient == null || !sshClient.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SSH connection is not available')),
        );
      }
      return;
    }

    try {
      final command = direction == SplitDirection.horizontal
          ? _resolveMuxCmd(TmuxCommands.splitWindowHorizontal(target: paneId))
          : _resolveMuxCmd(TmuxCommands.splitWindowVertical(target: paneId));
      await sshClient.exec(command);
      await _refreshSessionTree();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to split pane: $e')),
        );
      }
    }
  }

  void _showPaneSelector(TmuxState tmuxState) {
    final window = tmuxState.activeWindow;
    if (window == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Pane',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outline),
                // ペインレイアウトのビジュアル表示
                _PaneLayoutVisualizer(
                  panes: window.panes,
                  activePaneId: tmuxState.activePaneId,
                  onPaneSelected: (paneId) {
                    Navigator.pop(sheetContext);
                    _selectPane(paneId);
                  },
                  onSplitRequested: (paneId, direction) {
                    Navigator.pop(sheetContext);
                    _splitPane(paneId, direction);
                  },
                ),
                Divider(height: 1, color: colorScheme.outline),
                // ペイン一覧
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: window.panes.length,
                    itemBuilder: (context, index) {
                      final pane = window.panes[index];
                      final isActive = pane.id == tmuxState.activePaneId;
                      // タイトルを優先表示、なければコマンド名、それもなければPaneインデックス
                      final paneTitle = pane.title?.isNotEmpty == true
                          ? pane.title!
                          : (pane.currentCommand?.isNotEmpty == true
                              ? pane.currentCommand!
                              : 'Pane ${pane.index}');
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? colorScheme.primary.withValues(alpha: 0.5)
                                  : colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${pane.index}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          paneTitle,
                          style: TextStyle(
                            color: isActive ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${pane.width}x${pane.height}',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
                        ),
                        trailing: isActive
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _selectPane(pane.id);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Breadcrumb helpers
  // ---------------------------------------------------------------------------

  Widget _buildBreadcrumbItem(
    String label, {
    IconData? icon,
    bool isActive = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: isActive
                    ? colorScheme.primary
                    : (isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label.isEmpty ? '...' : label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: isActive || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? colorScheme.primary
                    : (isSelected ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: isActive
                    ? colorScheme.primary.withValues(alpha: 0.7)
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbSeparator() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '/',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w300,
          color: colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pane indicator
  // ---------------------------------------------------------------------------

  Widget _buildPaneIndicator(TmuxState tmuxState) {
    final window = tmuxState.activeWindow;
    final panes = window?.panes ?? [];
    final activePaneId = tmuxState.activePaneId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (panes.isEmpty) {
      return const SizedBox.shrink();
    }

    const double indicatorSize = 48.0;

    return GestureDetector(
      onTap: () => _showPaneSelector(tmuxState),
      child: Opacity(
        opacity: 0.5,
        child: Container(
          width: indicatorSize,
          height: indicatorSize,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: CustomPaint(
            size: Size(indicatorSize - 4, indicatorSize - 4),
            painter: _PaneLayoutPainter(
              panes: panes,
              activePaneId: activePaneId,
              activeColor: colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper widgets and painters (unchanged from original)
// =============================================================================

/// ペインレイアウトを描画するCustomPainter
class _PaneLayoutPainter extends CustomPainter {
  final List<TmuxPane> panes;
  final String? activePaneId;
  final Color activeColor;
  final bool isDark;

  _PaneLayoutPainter({
    required this.panes,
    this.activePaneId,
    required this.activeColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (panes.isEmpty) return;

    int maxRight = 0;
    int maxBottom = 0;
    for (final pane in panes) {
      final right = pane.left + pane.width;
      final bottom = pane.top + pane.height;
      if (right > maxRight) maxRight = right;
      if (bottom > maxBottom) maxBottom = bottom;
    }

    if (maxRight == 0 || maxBottom == 0) return;

    final scaleX = size.width / maxRight;
    final scaleY = size.height / maxBottom;
    final gap = 1.0;

    for (final pane in panes) {
      final isActive = pane.id == activePaneId;

      final left = pane.left * scaleX;
      final top = pane.top * scaleY;
      final width = pane.width * scaleX - gap;
      final height = pane.height * scaleY - gap;

      final rect = Rect.fromLTWH(left, top, width, height);

      final bgPaint = Paint()
        ..color = isActive
            ? activeColor.withValues(alpha: 0.3)
            : (isDark ? Colors.black45 : Colors.grey.shade300);
      canvas.drawRect(rect, bgPaint);

      final borderPaint = Paint()
        ..color = isActive ? activeColor : (isDark ? Colors.white30 : Colors.grey.shade500)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 1.5 : 1.0;
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaneLayoutPainter oldDelegate) {
    return panes != oldDelegate.panes ||
        activePaneId != oldDelegate.activePaneId ||
        activeColor != oldDelegate.activeColor ||
        isDark != oldDelegate.isDark;
  }
}

/// ペインレイアウトをインタラクティブに表示するウィジェット
class _PaneLayoutVisualizer extends StatefulWidget {
  final List<TmuxPane> panes;
  final String? activePaneId;
  final void Function(String paneId) onPaneSelected;
  final void Function(String paneId, SplitDirection direction)? onSplitRequested;

  const _PaneLayoutVisualizer({
    required this.panes,
    this.activePaneId,
    required this.onPaneSelected,
    this.onSplitRequested,
  });

  @override
  State<_PaneLayoutVisualizer> createState() => _PaneLayoutVisualizerState();
}

class _PaneLayoutVisualizerState extends State<_PaneLayoutVisualizer> {
  String? _splitModeActivePaneId;

  @override
  Widget build(BuildContext context) {
    if (widget.panes.isEmpty) return const SizedBox.shrink();

    int maxRight = 0;
    int maxBottom = 0;
    for (final pane in widget.panes) {
      final right = pane.left + pane.width;
      final bottom = pane.top + pane.height;
      if (right > maxRight) maxRight = right;
      if (bottom > maxBottom) maxBottom = bottom;
    }

    if (maxRight == 0 || maxBottom == 0) return const SizedBox.shrink();

    final aspectRatio = maxRight / maxBottom;

    return Container(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: aspectRatio.clamp(0.5, 3.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerWidth = constraints.maxWidth;
            final containerHeight = constraints.maxHeight;

            final scaleX = containerWidth / maxRight;
            final scaleY = containerHeight / maxBottom;
            const gap = 2.0;

            return Stack(
              children: widget.panes.map((pane) {
                final isActive = pane.id == widget.activePaneId;
                final isSplitMode = _splitModeActivePaneId == pane.id;

                final left = pane.left * scaleX;
                final top = pane.top * scaleY;
                final width = pane.width * scaleX - gap;
                final height = pane.height * scaleY - gap;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: GestureDetector(
                    onTap: () => _handlePaneTap(pane, isActive, width, height),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isActive
                            ? DesignColors.primary.withValues(alpha: 0.3)
                            : Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isActive
                              ? DesignColors.primary
                              : Colors.white.withValues(alpha: 0.3),
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: _buildPaneContent(
                          pane: pane,
                          isActive: isActive,
                          isSplitMode: isSplitMode,
                          width: width,
                          height: height,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  static const _minInlineWidth = 80.0;
  static const _minInlineHeight = 60.0;

  void _handlePaneTap(TmuxPane pane, bool isActive, double width, double height) {
    if (isActive && widget.onSplitRequested != null) {
      if (width < _minInlineWidth || height < _minInlineHeight) {
        _showSplitDialog(pane);
      } else {
        setState(() {
          _splitModeActivePaneId =
              _splitModeActivePaneId == pane.id ? null : pane.id;
        });
      }
    } else {
      widget.onPaneSelected(pane.id);
    }
  }

  void _showSplitDialog(TmuxPane pane) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(
            'Split Pane ${pane.index}',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CustomPaint(
                  size: const Size(24, 24),
                  painter: _SplitRightIconPainter(color: colorScheme.primary),
                ),
                title: const Text('Split Right'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  widget.onSplitRequested!(pane.id, SplitDirection.horizontal);
                },
              ),
              ListTile(
                leading: CustomPaint(
                  size: const Size(24, 24),
                  painter: _SplitDownIconPainter(color: colorScheme.primary),
                ),
                title: const Text('Split Down'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  widget.onSplitRequested!(pane.id, SplitDirection.vertical);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaneContent({
    required TmuxPane pane,
    required bool isActive,
    required bool isSplitMode,
    required double width,
    required double height,
  }) {
    if (isActive && isSplitMode) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${pane.index}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: width > 60 ? 18 : 14,
              fontWeight: FontWeight.w700,
              color: DesignColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSplitButton(
                painter: _SplitRightIconPainter(color: DesignColors.primary),
                onTap: () => widget.onSplitRequested!(
                  pane.id,
                  SplitDirection.horizontal,
                ),
              ),
              const SizedBox(width: 8),
              _buildSplitButton(
                painter: _SplitDownIconPainter(color: DesignColors.primary),
                onTap: () => widget.onSplitRequested!(
                  pane.id,
                  SplitDirection.vertical,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${pane.index}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: width > 60 ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: isActive
                ? DesignColors.primary
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
        if (isActive && widget.onSplitRequested != null && width > 60 && height > 40) ...[
          const SizedBox(height: 2),
          Text(
            'Tap to split',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              color: DesignColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ] else if (width > 80 && height > 50) ...[
          const SizedBox(height: 2),
          Text(
            '${pane.width}x${pane.height}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSplitButton({
    required CustomPainter painter,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: DesignColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: CustomPaint(
            size: const Size(20, 20),
            painter: painter,
          ),
        ),
      ),
    );
  }
}

/// 右分割アイコン
class _SplitRightIconPainter extends CustomPainter {
  final Color color;

  _SplitRightIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final pad = w * 0.1;
    final mid = w * 0.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, pad, w - pad * 2, h - pad * 2),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawLine(Offset(mid, pad), Offset(mid, h - pad), paint);

    final plusPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final cx = mid + (w - pad - mid) / 2;
    final cy = h / 2;
    final plusSize = w * 0.12;
    canvas.drawLine(Offset(cx - plusSize, cy), Offset(cx + plusSize, cy), plusPaint);
    canvas.drawLine(Offset(cx, cy - plusSize), Offset(cx, cy + plusSize), plusPaint);
  }

  @override
  bool shouldRepaint(covariant _SplitRightIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 下分割アイコン
class _SplitDownIconPainter extends CustomPainter {
  final Color color;

  _SplitDownIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final pad = w * 0.1;
    final mid = h * 0.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, pad, w - pad * 2, h - pad * 2),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawLine(Offset(pad, mid), Offset(w - pad, mid), paint);

    final plusPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final cx = w / 2;
    final cy = mid + (h - pad - mid) / 2;
    final plusSize = w * 0.12;
    canvas.drawLine(Offset(cx - plusSize, cy), Offset(cx + plusSize, cy), plusPaint);
    canvas.drawLine(Offset(cx, cy - plusSize), Offset(cx, cy + plusSize), plusPaint);
  }

  @override
  bool shouldRepaint(covariant _SplitDownIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 入力ダイアログのコンテンツ（複数行対応、Shift+Enterで改行）
class _InputDialogContent extends StatefulWidget {
  final String initialValue;
  final void Function(String value) onValueChanged;
  final Future<void> Function(String value) onSend;

  const _InputDialogContent({
    this.initialValue = '',
    required this.onValueChanged,
    required this.onSend,
  });

  @override
  State<_InputDialogContent> createState() => _InputDialogContentState();
}

class _InputDialogContentState extends State<_InputDialogContent> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _onTextChanged() {
    widget.onValueChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.onKeyEvent = null;
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      if (isShiftPressed) {
        _insertNewline();
        return KeyEventResult.handled;
      } else {
        _handleSend();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, '\n');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await widget.onSend(_controller.text);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Enter Command',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Shift+Enter: newline',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 200,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: GoogleFonts.jetBrainsMono(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Type your command... (Enter to send)',
                hintStyle: GoogleFonts.jetBrainsMono(
                  color: isDark ? DesignColors.textMuted : DesignColors.textMutedLight,
                ),
                filled: true,
                fillColor: isDark ? DesignColors.inputDark : DesignColors.inputLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Execute',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
