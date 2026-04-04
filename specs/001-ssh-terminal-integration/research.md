# Research: SSH/Terminal Integration

**Date**: 2026-01-11
**Branch**: `001-ssh-terminal-integration`

## Overview

existingcodebaseanalysis、SSH/TerminalintegrationrequiredDecision。

## existingcomponentanalysis

### 1. SshClient (`lib/services/ssh/ssh_client.dart`)

**state**: completeimplement

| method | purpose | integration |
|---------|------|-------------|
| `connect()` | SSH connectionestablishment | connectionstart |
| `startShell()` | PTYshellstart | tmuxattachrequired |
| `setEventHandlers()` | backsettings | datareceive→Terminaldisplay |
| `write()` | datasend | Key Inputsend |
| `exec()` | commandrun | tmuxcommandrun |
| `resize()` | PTYresize | screensizesync |

### 2. TmuxCommands (`lib/services/tmux/tmux_commands.dart`)

**state**: completeimplement

| method | purpose | integration |
|---------|------|-------------|
| `listSessions()` | sessionlistretrieve | connectioninitial |
| `attachSession()` | sessionattach | shellrun |
| `newSession()` | newsessioncreate | sessionwhen |
| `sendKeys()` | keysend | （shell） |

### 3. MuxTerminalController (`lib/services/terminal/terminal_controller.dart`)

**state**: completeimplement

| /method | purpose | integration |
|-------------------|------|-------------|
| `terminal` | xterm | UIwidget |
| `onInput` | input | SSHsend |
| `onResize` | resize | PTYresizesync |
| `write()` | datawrite | SSHoutputdisplay |

### 4. Providers

| Provider | state | integration |
|----------|------|-------------|
| `sshProvider` | implement | SSH connectionstatemanagement |
| `terminalProvider` | implement | Terminalstatemanagement |
| `tmuxProvider` | implement | tmux sessionstatemanagement |
| `connectionsProvider` | implement | connection settingsretrieve |
| `keysProvider` | implement | SSHkeydatamanagement |

## Decision

### Decision 1: tmuxattach

**Decision**: shell `tmux attach-session` commandrun

**Rationale**:
- SSHshellPTY
- `exec()`run、shellclose
- shellattach、PTYtmuxintegration

**（）**:
- `exec("tmux attach")`: sessioncloseSSHdisconnect
- separatesessionattach: 

**implement**:
```dart
// shellstart
await sshClient.startShell();

// tmuxattachcommandshellsend
final attachCmd = TmuxCommands.attachSession(sessionName);
sshClient.write('$attachCmd\n');
```

### Decision 2: connection

**Decision**: SshProvidersettings、TerminalProvider

**Rationale**:
- : SSH→datareceive、Terminal→display
- test: eachindependenttestpossible
- existing

**implement**:
```
SshClient.onData → SshProvider → TerminalProvider.write → Terminaldisplay
MuxTerminalController.onInput → TerminalScreen → SshProvider.write → SSHsend
```

### Decision 3: authenticationinformationretrieve

**Decision**: `flutter_secure_storage`retrieve（KeychainService）

**Rationale**:
- authenticationinformation（password/private key）securestoragesaved
- KeysProviderdata、keyseparateretrieve

**implement**:
```dart
// passwordauthenticationwhen
final password = await secureStorage.read(key: 'connection_${connection.id}_password');

// keyauthenticationwhen
final privateKey = await secureStorage.read(key: 'ssh_key_${connection.keyId}_private');
```

****: KeychainServicewhen、flutter_secure_storage

### Decision 4: error

**Decision**: 3error

|  | error | support |
|---------|-----------|------|
| SSH connection | connectionerror、authenticationerror | SnackBar + reconnect |
| tmuxoperation | session、serverstart | automaticcreate or message |
|  | network disconnect | disconnectnotification + reconnect |

### Decision 5: terminal-SSHdata

**Decision**: connection

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Terminal UI    │     │   SshProvider   │     │   SSH Server    │
│  (xterm Widget) │     │                 │     │   (tmux)        │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  onInput (keys)       │                       │
         ├──────────────────────►│      write()          │
         │                       ├──────────────────────►│
         │                       │                       │
         │                       │      onData()         │
         │  write() (display)    │◄──────────────────────┤
         │◄──────────────────────┤                       │
         │                       │                       │
```

## resolve

 - allDecisioncomplete

## 

1. `data-model.md` - datadetails
2. `contracts/` - interface
3. `quickstart.md` - implement



