# Quickstart: SSH/Terminal Integration

**Date**: 2026-01-11
**Branch**: `001-ssh-terminal-integration`

## Overview

documentation、SSH/Terminal Integrationimplement。
`terminal_screen.dart`2TODOcommentresolveSteps。

## Prerequisites

- Flutter 3.24+ / Dart 3.10+
- existingservice
  - `lib/services/ssh/ssh_client.dart`
  - `lib/services/tmux/tmux_commands.dart`
  - `lib/providers/ssh_provider.dart`

## implement

### Step 1: TerminalScreenProvideradd

`lib/screens/terminal/terminal_screen.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../providers/connection_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tmux_provider.dart';
import '../../services/ssh/ssh_client.dart';
import '../../services/tmux/tmux_commands.dart';
import '../../services/tmux/tmux_parser.dart';

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  // add: storage
  final _secureStorage = const FlutterSecureStorage();

  // add: connectionstate
  bool _isConnecting = false;
  String? _connectionError;
```

### Step 2: _connectAndAttach()implement (39lineTODO)

```dart
Future<void> _connectAndAttach() async {
  setState(() {
    _isConnecting = true;
    _connectionError = null;
  });

  try {
    // 1. connectioninformationretrieve
    final connection = ref.read(connectionsProvider.notifier).getById(Widget.connectionId);
    if (connection == null) {
      throw Exception('Connection not found');
    }

    // 2. authenticationinformationretrieve
    final options = await _getAuthOptions(connection);

    // 3. SSH connection
    final sshNotifier = ref.read(sshProvider.notifier);
    await sshNotifier.connect(connection, options);

    // 4. settings
    final sshClient = sshNotifier.client;
    if (sshClient != null) {
      sshClient.setEventHandlers(SshEvents(
        onData: (data) {
          _terminal.write(String.fromCharCodes(data));
        },
        onClose: _handleDisconnect,
        onError: _handleError,
      ));
    }

    // 5. tmux sessionlistretrieve
    final sessionsOutput = await sshClient?.exec(TmuxCommands.listSessions());
    if (sessionsOutput != null) {
      final sessions = TmuxParser.parseSessions(sessionsOutput);
      ref.read(tmuxProvider.notifier).updateSessions(sessions);

      // 6. sessionattachnewcreate
      if (sessions.isNotEmpty) {
        final sessionName = Widget.sessionName ?? sessions.first.name;
        sshClient?.write('${TmuxCommands.attachSession(sessionName)}\n');
        ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
      } else {
        final newSessionName = 'muxpod-${DateTime.now().millisecondsSinceEpoch}';
        sshClient?.write('${TmuxCommands.newSession(name: newSessionName, detached: false)}\n');
        ref.read(tmuxProvider.notifier).setActiveSession(newSessionName);
      }
    }

    setState(() {
      _isConnecting = false;
    });
  } catch (e) {
    setState(() {
      _isConnecting = false;
      _connectionError = e.toString();
    });
    _showErrorSnackBar(e.toString());
  }
}

Future<SshConnectOptions> _getAuthOptions(Connection connection) async {
  if (connection.authMethod == 'key' && connection.keyId != null) {
    final privateKey = await _secureStorage.read(
      key: 'ssh_key_${connection.keyId}_private',
    );
    final passphrase = await _secureStorage.read(
      key: 'ssh_key_${connection.keyId}_passphrase',
    );
    return SshConnectOptions(privateKey: privateKey, passphrase: passphrase);
  } else {
    final password = await _secureStorage.read(
      key: 'connection_${connection.id}_password',
    );
    return SshConnectOptions(password: password);
  }
}

void _handleDisconnect() {
  if (mounted) {
    _showErrorSnackBar('Connection closed');
    Navigator.of(context).pop();
  }
}

void _handleError(Object error) {
  if (mounted) {
    _showErrorSnackBar('Error: $error');
  }
}

void _showErrorSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: _connectAndAttach,
      ),
    ),
  );
}
```

### Step 3: _sendKey()implement (287lineTODO)

```dart
void _sendKey(String key) {
  final sshState = ref.read(sshProvider);
  if (sshState.isConnected) {
    ref.read(sshProvider.notifier).write(key);
  }
  // （）
  // _terminal.write(key);
}
```

### Step 4: dispose

```dart
@override
void dispose() {
  _terminalController.dispose();
  // SSH connectioncleanup
  ref.read(sshProvider.notifier).disconnect();
  super.dispose();
}
```

### Step 5: UIloading/errordisplayadd

`build()`method:

```dart
@override
Widget build(BuildContext context) {
  final sshState = ref.watch(sshProvider);

  return Scaffold(
    backgroundColor: DesignColors.backgroundDark,
    body: Stack(
      children: [
        Column(
          children: [
            _buildBreadcrumbHeader(),
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _terminalController,
                // ... existingsettings
              ),
            ),
            SpecialKeysBar(
              onKeyPressed: _sendKey,
              onInputTap: _showInputDialog,
            ),
          ],
        ),
        // loadingoverlay
        if (_isConnecting || sshState.isConnecting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        // errordisplay
        if (_connectionError != null || sshState.hasError)
          _buildErrorOverlay(sshState.error ?? _connectionError),
      ],
    ),
  );
}

Widget _buildErrorOverlay(String? error) {
  return Container(
    color: Colors.black87,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            error ?? 'Connection error',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _connectAndAttach,
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
```

## test

### manualtest

1. Androidemulatorphysical deviceappstart
2. connectionadd（enabledSSHserver）
3. connectionterminal screen
4. tmux sessiondisplayverify
5. Key Inputsendverify

### integrationtest（future）

```dart
testWidgets('SSH connection establishes and attaches to tmux', (tester) async {
  // Mock SSH client
  // Mock secure storage
  // Pump TerminalScreen
  // Verify connection flow
});
```

## troubleshooting

| issue | cause | solution |
|-----|------|-------|
| connection timeout | issue | host/portverify |
| authenticationerror | password/keyinvalid | authenticationinformationresettings |
| tmux not found | servertmux | tmuxinstall |
| display | ANSIescapeissue | terminalverify |

## reference

- [dartssh2 documentation](https://pub.dev/packages/dartssh2)
- [xterm.dart documentation](https://pub.dev/packages/xterm)
- [tmux manual](https://man7.org/linux/man-pages/man1/tmux.1.html)



