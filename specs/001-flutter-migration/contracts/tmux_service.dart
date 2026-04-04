/// Tmux Service Contract
///
/// tmux session/window/paneoperationserviceinterface。
/// SSHservicedependency、tmuxcommand。

import 'dart:async';

import '../models/tmux.dart';

/// tmuxserviceinterface
abstract class TmuxService {
  /// sessionlistretrieve
  Future<List<TmuxSession>> listSessions(String connectionId);

  /// windowlistretrieve
  Future<List<TmuxWindow>> listWindows({
    required String connectionId,
    required String sessionName,
  });

  /// panelistretrieve
  Future<List<TmuxPane>> listPanes({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
  });

  /// panecontentsretrieve
  Future<List<String>> capturePane({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
    required int paneIndex,
    int? startLine,
    int? endLine,
    bool escapeSequences = true,
  });

  /// keysend
  Future<void> sendKeys({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
    required int paneIndex,
    required String keys,
    bool literal = false,
  });

  /// paneselect
  Future<void> selectPane({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
    required int paneIndex,
  });

  /// windowselect
  Future<void> selectWindow({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
  });

  /// sessioncreate
  Future<void> newSession({
    required String connectionId,
    required String name,
  });

  /// sessiondelete
  Future<void> killSession({
    required String connectionId,
    required String name,
  });

  /// paneresize
  Future<void> resizePane({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
    required int paneIndex,
    required int width,
    required int height,
  });

  /// tmuxinstallverify
  Future<bool> isTmuxInstalled(String connectionId);

  /// tmuxversionretrieve
  Future<String?> getTmuxVersion(String connectionId);
}



