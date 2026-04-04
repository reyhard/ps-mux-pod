# Data Model: SSH/Terminal Integration

**Date**: 2026-01-11
**Branch**: `001-ssh-terminal-integration`

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MuxPod Data Flow                            │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Connection  │────►│  SshClient   │────►│  SSH Server  │
│  (settings)      │     │  (connection)      │     │  ()  │
└──────────────┘     └──────┬───────┘     └──────┬───────┘
                           │                     │
                           │ startShell()        │
                           ▼                     │
                    ┌──────────────┐             │
                    │  SSHSession  │◄────────────┘
                    │  (PTY)       │
                    └──────┬───────┘
                           │
                           │ write("tmux attach")
                           ▼
                    ┌──────────────┐
                    │ TmuxSession  │
                    │  (session) │
                    └──────┬───────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ TmuxPane │    │ TmuxPane │    │ TmuxPane │
    │ (pane) │    │ (pane) │    │ (pane) │
    └──────────┘    └──────────┘    └──────────┘
```

## existing

### Connection (Connection Settings)

**file**: `lib/providers/connection_provider.dart`

```dart
class Connection {
  final String id;           // UUID
  final String name;         // display
  final String host;         // host name/IP
  final int port;            // port (default: 22)
  final String username;     // user
  final String authMethod;   // 'password' | 'key'
  final String? keyId;       // SSHkeyID (authMethod='key'when)
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
}
```

**validation**:
- `host`: 
- `port`: 1-65535
- `username`: 
- `authMethod`: 'password'  'key'

### SshKeyMeta (SSH Key Metadata)

**file**: `lib/providers/key_provider.dart`

```dart
class SshKeyMeta {
  final String id;           // UUID
  final String name;         // display
  final String type;         // 'rsa' | 'ed25519' | 'ecdsa'
  final String? publicKey;   // public key (display)
  final bool hasPassphrase;  // passphrase
  final DateTime createdAt;
  final String? comment;     // comment
}
```

****: private key `flutter_secure_storage` separatesave

### TmuxSession (tmux Session)

**file**: `lib/services/tmux/tmux_parser.dart`

```dart
class TmuxSession {
  final String name;         // session
  final String? id;          // sessionID ($0, $1, ...)
  final DateTime? created;   // create
  final bool attached;       // attachstate
  final int windowCount;     // windowcount
  final List<TmuxWindow> windows;
}
```

### TmuxWindow (tmux Window)

**file**: `lib/services/tmux/tmux_parser.dart`

```dart
class TmuxWindow {
  final int index;           // window
  final String? id;          // windowID (@0, @1, ...)
  final String name;         // window
  final bool active;         // active state
  final int paneCount;       // panecount
  final Set<TmuxWindowFlag> flags;
  final List<TmuxPane> panes;
}
```

### TmuxPane (tmux Pane)

**file**: `lib/services/tmux/tmux_parser.dart`

```dart
class TmuxPane {
  final int index;           // pane
  final String id;           // paneID (%0, %1, ...)
  final bool active;         // active state
  final String? currentCommand;
  final String? title;
  final int width;           // width (cols)
  final int height;          // height (rows)
  final int cursorX;
  final int cursorY;
}
```

## State Model

### SshState

**file**: `lib/providers/ssh_provider.dart`

```dart
class SshState {
  final SshConnectionState connectionState;  // disconnected|connecting|connected|error
  final String? error;
  final String? sessionTitle;
}
```

**state**:
```
disconnected ──connect()──► connecting
connecting ───success───► connected
connecting ───failure───► error
connected ──disconnect()─► disconnected
connected ───error──────► error
error ────retry()──────► connecting
```

### TerminalState

**file**: `lib/providers/terminal_provider.dart`

```dart
class TerminalState {
  final MuxTerminalController? controller;
  final bool isInitialized;
  final int cols;
  final int rows;
  final String? title;
}
```

### TmuxState

**file**: `lib/providers/tmux_provider.dart`

```dart
class TmuxState {
  final List<TmuxSession> sessions;
  final String? activeSessionName;
  final int? activeWindowIndex;
  final String? activePaneId;
  final bool isLoading;
  final String? error;
}
```

## Data Flow

### Connection Flow

```
1. The user can connection
   ↓
2. ConnectionconnectionIdretrieve
   ↓
3. SshProviderconnectionstart
   - SshClient.connect(host, port, username, options)
   - SshClient.startShell()
   ↓
4. settings
   - onData → Terminal.write()
   - onClose → disconnectprocessing
   - onError → errordisplay
   ↓
5. tmux sessionlistretrieve
   - SshClient.exec(TmuxCommands.listSessions())
   ↓
6. sessionattach
   - SshClient.write("tmux attach -t session\n")
   ↓
7. connectioncomplete
```

### Key Input Flow

```
1. The user can Key Input
   ↓
2. MuxTerminalController.onInput
   ↓
3. TerminalScreen._sendKey()
   ↓
4. SshProvider.write(data)
   ↓
5. SshClient.write(data)
   ↓
6. SSH → tmux → shell
```

### Output Display Flow

```
1. SSH Server → datasend
   ↓
2. SshClient.onData
   ↓
3. SshEvents.onData callback
   ↓
4. TerminalProvider.write()
   ↓
5. Terminal.write() (xterm)
   ↓
6. screenupdate
```

## Secure Storage Keys

| key | purpose | save |
|-----|------|--------------|
| `connection_{id}_password` | connectionpassword | connection settingssave |
| `ssh_key_{id}_private` | SSHprivate key | keyport |
| `ssh_key_{id}_passphrase` | keypassphrase | keyport |



