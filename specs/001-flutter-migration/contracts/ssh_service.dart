/// SSH Service Contract
///
/// SSHConnection Managementserviceinterface。
/// dartssh2implementdetails、。

import 'dart:async';
import 'dart:typed_data';

import '../models/connection.dart';
import '../models/ssh_key.dart';

/// SSH connectionstate
enum ConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

/// SSH connectionstatechange
class ConnectionStateEvent {
  final String connectionId;
  final ConnectionStatus status;
  final String? error;
  final int? latencyMs;

  const ConnectionStateEvent({
    required this.connectionId,
    required this.status,
    this.error,
    this.latencyMs,
  });
}

/// SSHshellsession
abstract class SshShellSession {
  /// shelloutput
  Stream<Uint8List> get stdout;

  /// shellerroroutput
  Stream<Uint8List> get stderr;

  /// shellcloseFuture
  Future<void> get done;

  /// datasend
  void write(Uint8List data);

  /// characterscolumnsend（UTF-8code）
  void writeString(String data);

  /// PTYsizechange
  Future<void> resize(int width, int height);

  /// shell
  Future<void> close();
}

/// SSHserviceinterface
abstract class SshService {
  /// connectionstate
  Stream<ConnectionStateEvent> get connectionState;

  /// SSH connection（passwordauthentication）
  Future<void> connectWithPassword({
    required Connection connection,
    required String password,
  });

  /// SSH connection（keyauthentication）
  Future<void> connectWithKey({
    required Connection connection,
    required SSHKey key,
    String? passphrase,
  });

  /// connectionstateretrieve
  ConnectionStatus getStatus(String connectionId);

  /// shellsessionstart
  Future<SshShellSession> startShell({
    required String connectionId,
    int? width,
    int? height,
    String term = 'xterm-256color',
  });

  /// commandrun（）
  Future<SshExecResult> exec({
    required String connectionId,
    required String command,
  });

  /// disconnect
  Future<void> disconnect(String connectionId);

  /// allconnectiondisconnect
  Future<void> disconnectAll();

  /// keysend
  Future<void> ping(String connectionId);
}

/// commandrunresult
class SshExecResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  const SshExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  bool get success => exitCode == 0;
}



