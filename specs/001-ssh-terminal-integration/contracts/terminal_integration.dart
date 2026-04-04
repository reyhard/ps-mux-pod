/// SSH/Terminal Integrationinterface
///
/// fileimplement、
/// implement lib/ existingfileperform。
library;

import 'dart:async';
import 'dart:typed_data';

// ============================================================
// TerminalScreen addmethod
// ============================================================

/// TerminalScreenimplementintegrationinterface
abstract interface class ITerminalIntegration {
  /// SSH connectiontmuxattach
  ///
  /// implementrequirements:
  /// 1. connectionIdconnectioninformationretrieve
  /// 2. authenticationinformationsecurestorageretrieve
  /// 3. SshProviderSSH connection
  /// 4. tmux sessionlistretrieve
  /// 5. attach、newcreate
  /// 6. SSHTerminalconnection
  ///
  /// error:
  /// - connectionerror: SnackBarerrordisplay
  /// - authenticationerror: SnackBarerrordisplay
  /// - tmux: messagedisplay
  Future<void> connectAndAttach();

  /// keySSHsend
  ///
  /// implementrequirements:
  /// 1. SshProvider.isConnectedverify
  /// 2. SshProvider.write()datasend
  ///
  /// [key] sendkeydata（ESC、CTRL+Cspecialkey）
  void sendKey(String key);

  /// terminalresizeprocessing
  ///
  /// implementrequirements:
  /// 1. SshProvider.resize()PTYresize
  ///
  /// [cols] count
  /// [rows] rows
  void onTerminalResize(int cols, int rows);

  /// cleanupprocessing
  ///
  /// implementrequirements:
  /// 1. SSH
  /// 2. SshProvider.disconnect()
  Future<void> cleanup();
}

// ============================================================
// SshProvider addmethod
// ============================================================

/// SshProviderimplementaddinterface
abstract interface class ISshProviderExtensions {
  /// tmux sessionlistretrieve
  ///
  /// implement:
  /// ```dart
  /// final output = await client.exec(TmuxCommands.listSessions());
  /// return TmuxParser.parseSessions(output);
  /// ```
  Future<List<TmuxSessionInfo>> listTmuxSessions();

  /// tmux sessionattach
  ///
  /// implement:
  /// ```dart
  /// final cmd = TmuxCommands.attachSession(sessionName);
  /// client.write('$cmd\n');
  /// ```
  void attachTmuxSession(String sessionName);

  /// newtmux sessioncreate
  ///
  /// implement:
  /// ```dart
  /// final cmd = TmuxCommands.newSession(name: sessionName, detached: false);
  /// client.write('$cmd\n');
  /// ```
  void createTmuxSession(String sessionName);
}

// ============================================================
// 
// ============================================================

/// SSHdatareceive
///
/// [data] receivedata
typedef SshDataHandler = void Function(Uint8List data);

/// SSHdisconnect
typedef SshCloseHandler = void Function();

/// SSHerror
///
/// [error] error
typedef SshErrorHandler = void Function(Object error);

// ============================================================
// state
// ============================================================

/// TerminalScreenstate
///
/// ```
/// State: idle
///   ↓ initState()
/// State: connecting
///   ↓ connectAndAttach() success
/// State: connected
///   ↓ error / disconnect
/// State: error / idle
/// ```
enum TerminalConnectionState {
  /// initialstate
  idle,

  /// SSH connectionin progress
  connecting,

  /// connectioncomplete（tmuxattach）
  connected,

  /// errorstate
  error,

  /// disconnect
  disconnected,
}

// ============================================================
// error
// ============================================================

/// terminalintegrationerror
sealed class TerminalIntegrationError implements Exception {
  String get message;
}

/// connection settings
class ConnectionNotFoundError implements TerminalIntegrationError {
  final String connectionId;
  ConnectionNotFoundError(this.connectionId);

  @override
  String get message => 'Connection not found: $connectionId';
}

/// authenticationinformation
class AuthenticationDataNotFoundError implements TerminalIntegrationError {
  final String connectionId;
  AuthenticationDataNotFoundError(this.connectionId);

  @override
  String get message => 'Authentication data not found for connection: $connectionId';
}

/// tmuxuse
class TmuxNotAvailableError implements TerminalIntegrationError {
  @override
  String get message => 'tmux is not installed or not available on the remote server';
}

// ============================================================
// （existing）
// ============================================================

/// TmuxSession
typedef TmuxSessionInfo = ({
  String name,
  String? id,
  bool attached,
  int windowCount,
});

// ============================================================
// testmock
// ============================================================

/// testmockSshClient
///
/// integrationtestmock
abstract interface class IMockSshClient {
  /// connection
  Future<void> mockConnect({
    required bool shouldSucceed,
    Duration delay,
  });

  /// datareceive
  void mockReceiveData(Uint8List data);

  /// error
  void mockError(Object error);

  /// disconnect
  void mockDisconnect();
}



