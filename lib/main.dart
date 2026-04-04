import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';
import 'package:flutter_muxpod/providers/settings_provider.dart';
import 'package:flutter_muxpod/screens/home_screen.dart';
import 'package:flutter_muxpod/screens/terminal/terminal_screen.dart';
import 'package:flutter_muxpod/services/deep_link/deep_link_service.dart';
import 'package:flutter_muxpod/services/license_service.dart';
import 'package:flutter_muxpod/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register font licenses
  LicenseService.registerLicenses();

  // Make the status bar transparent
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _deepLinkService = DeepLinkService();
  StreamSubscription<DeepLinkData>? _linkSubscription;
  bool _initialLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Set up hot link monitoring regardless of whether initialization succeeds
    _linkSubscription = _deepLinkService.linkStream.listen(_handleDeepLink);

    await _deepLinkService.initialize();

    // Process the cold-start initial link after connection data has loaded
    if (_deepLinkService.initialLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitForConnectionsAndHandleInitialLink();
      });
    }
  }

  Future<void> _waitForConnectionsAndHandleInitialLink() async {
    if (_initialLinkHandled) return;

    // Wait for connection data to load (up to 3 seconds)
    for (int i = 0; i < 30; i++) {
      final state = ref.read(connectionsProvider);
      if (!state.isLoading) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Wait for the navigator to be ready (up to 1 second)
    for (int i = 0; i < 10; i++) {
      if (_navigatorKey.currentState != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final initialLink = _deepLinkService.initialLink;
    if (initialLink != null && !_initialLinkHandled) {
      _initialLinkHandled = true;
      _handleDeepLink(initialLink);
    }
  }

  void _handleDeepLink(DeepLinkData data) {
    if (!data.hasTarget) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final connection = ref.read(connectionsProvider.notifier)
        .findByDeepLinkIdOrName(data.server!);

    if (connection == null) {
      ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
        SnackBar(
          content: Text('Server not found: ${data.server}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // First pop the existing route stack back to home
    navigator.popUntil((route) => route.isFirst);

    // Push on the next frame so TerminalScreen.dispose() triggered by popUntil
    // can finish before ref.read hits an _elements assertion failure.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;

      nav.push(
        MaterialPageRoute(
          builder: (context) => TerminalScreen(
            connectionId: connection.id,
            sessionName: data.session,
            deepLinkWindowName: data.window,
            deepLinkPaneIndex: data.pane,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'MuxPod',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
