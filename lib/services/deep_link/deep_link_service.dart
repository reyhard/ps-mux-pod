import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Parsed deep link result
final class DeepLinkData {
  final String? server;
  final String? session;
  final String? window;
  final int? pane;

  const DeepLinkData({
    this.server,
    this.session,
    this.window,
    this.pane,
  });

  bool get hasTarget => server != null;

  @override
  String toString() =>
      'DeepLinkData(server: $server, session: $session, window: $window, pane: $pane)';
}

/// Service that handles deep links for the `muxpod://` URL scheme
///
/// URL format: `muxpod://connect?server=id&session=name&window=name&pane=index`
final class DeepLinkService {
  static const _tag = 'DeepLinkService';
  static const _channel = MethodChannel('com.muxpod.app/deeplink');

  final _linkController = StreamController<DeepLinkData>.broadcast();

  Stream<DeepLinkData> get linkStream => _linkController.stream;

  DeepLinkData? _initialLink;
  DeepLinkData? get initialLink => _initialLink;

  bool _initialized = false;

  /// Initialize. Handles both cold-start links and hot links.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Receive deep links from native code via MethodChannel
    _channel.setMethodCallHandler(_handleMethodCall);

    // Get the initial link for cold-start launches
    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialLink');
      if (initialUri != null) {
        final data = parseUri(initialUri);
        if (data.hasTarget) {
          _initialLink = data;
          developer.log('Initial deep link: $data', name: _tag);
        }
      }
    } on MissingPluginException {
      // Platform channel not implemented (for tests, etc.)
      developer.log('Deep link channel not available', name: _tag);
    } catch (e) {
      developer.log('Error getting initial link: $e', name: _tag);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final uri = call.arguments as String?;
      if (uri != null) {
        final data = parseUri(uri);
        if (data.hasTarget) {
          developer.log('Hot deep link received: $data', name: _tag);
          _linkController.add(data);
        }
      }
    }
  }

  /// Parse a URI string into DeepLinkData
  static DeepLinkData parseUri(String uriString) {
    try {
      final uri = Uri.parse(uriString);

      // Accept only the muxpod://connect?... format
      if (uri.scheme != 'muxpod') {
        return const DeepLinkData();
      }

      final server = uri.queryParameters['server'];
      final session = uri.queryParameters['session'];
      final window = uri.queryParameters['window'];
      final paneStr = uri.queryParameters['pane'];
      final pane = paneStr != null ? int.tryParse(paneStr) : null;

      return DeepLinkData(
        server: server,
        session: session,
        window: window,
        pane: pane,
      );
    } catch (e) {
      developer.log('Failed to parse deep link URI: $e', name: _tag);
      return const DeepLinkData();
    }
  }

  void dispose() {
    _linkController.close();
  }
}
