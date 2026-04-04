# Research: Flutter Migration

**Feature**: 001-flutter-migration
**Date**: 2026-01-11

## Executive Summary

MuxPodReact Native (Expo)Flutterlineanalysisresult。dartssh2 + xterm.dartoptimal、Pure Dartimplementdependencycompletepossible。

---

## 1. SSH connection (dartssh2)

### Decision
**dartssh2 2.13+** 。Pure Dartimplementdependency。

### Rationale
- TerminalStudio active
- xterm.dart same、integrationgood
- passwordauthentication + RSA/Ed25519keyauthenticationsupport
- PTY（256colorsupport）、key

### Key Patterns

**passwordauthentication:**
```dart
final socket = await SSHSocket.connect(host, port);
final client = SSHClient(
  socket,
  username: username,
  onPasswordRequest: () => password,
);
await client.authenticated;
```

**public keyauthentication:**
```dart
final client = SSHClient(
  socket,
  username: username,
  identities: [...SSHKeyPair.fromPem(privateKeyPem)],
);
```

**shellstart（PTY）:**
```dart
final shell = await client.shell(
  pty: SSHPtyConfig(
    width: 80,
    height: 24,
    term: 'xterm-256color',
  ),
);
```

**specialkeysend:**
```dart
shell.write(Uint8List.fromList([0x1B]));       // ESC
shell.write(Uint8List.fromList([0x03]));       // Ctrl+C
shell.write(Uint8List.fromList([0x1B, 0x5B, 0x41])); // key（）
```

### Alternatives Considered
- **ssh2** (Dart): 4update、dependency → 
- **WebSocket Proxy**: serverrequired、 → 

---

## 2. terminal (xterm.dart)

### Decision
**xterm 4.0+** 。dartssh2integrationgood。

### Rationale
- 60fps 
- ANSI 256color + colorsupport
- CJKcharactersemojicharacterssupport
- 

### Key Patterns

**TerminalViewintegration:**
```dart
late final terminal = Terminal();

TerminalView(
  terminal: terminal,
  theme: TerminalThemes.defaultTheme,
  autoResize: true,
)
```

**SSHoutputconnection:**
```dart
// output → Terminal
shell.stdout.listen((data) {
  terminal.write(utf8.decode(data));
});

// userinput → 
terminal.onOutput = (String output) {
  shell.write(utf8.encode(output));
};
```

**resizesync:**
```dart
terminal.onResize = (w, h) {
  session.setPtySize(columns: w, rows: h);
};
```

### Alternatives Considered
- implement:  → 
- react-native-terminal: RNdependency → 

---

## 3. statemanagement (Riverpod)

### Decision
**flutter_riverpod + riverpod_annotation (codegen)** 。

### Rationale
- AsyncNotifierProvider syncoperation
- .family connectionindependentstatemanagement
- autoDispose memory
- DI 

### Key Patterns

**SSH connection:**
```dart
@riverpod
class SshConnectionController extends _$SshConnectionController {
  @override
  FutureOr<SshConnection> build(String connectionId) async {
    ref.onDispose(() => _cleanup());
    return await _establishConnection(connectionId);
  }

  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    await _client?.close();
    state = AsyncValue.error('Disconnected', StackTrace.current);
  }
}

// : ref.watch(sshConnectionControllerProvider(connId))
```

**Provider:**
```
foundation:   sshConnectionProvider (family)
          ↓ dependency
main: tmuxSessionsProvider, terminalProvider
          ↓ dependency
UI:     selectedPaneProvider (StateProvider)
```

### Alternatives Considered
- **Provider**: sync → 
- **BLoC**:  → 
- **GetX**:  → 

---

## 4. securestorage

### Decision
- **data**: flutter_secure_storage（private key、password）
- **data**: shared_preferences（connection settingsdata）

### Rationale
- flutter_secure_storage: Android Keystore / iOS Keychain 、encrypted
- shared_preferences: high、settingsappropriate
- expo-secure-store 

### Key Patterns

**private keysave:**
```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'ssh_key_$id', value: privateKeyPem);
```

**authentication:**
```dart
final storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);
```

**connection settingssave:**
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('connections', jsonEncode(connections));
```

### Migration Strategy (RN → Flutter)
1. expo-secure-store dataJSONformatport
2. flutter_secure_storage reencryptedsave
3. keymaintain（`ssh_key_${id}`, `password_${id}`）

**note**: encryptedimplement、。The user first-timestartresettingsrequiredpossible。

### Alternatives Considered
- **flutter_keychain**: low → 
- **biometric_storage**: flutter_secure_storage → not needed

---

## 5. 

### Decision
**go_router** 。

### Rationale
- routing
- Deep link support
- Navigator 2.0 base
- Riverpod integrationgood

### Key Patterns

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => ConnectionsScreen()),
    GoRoute(
      path: '/terminal/:connectionId',
      builder: (_, state) => TerminalScreen(
        connectionId: state.pathParameters['connectionId']!,
      ),
    ),
    GoRoute(path: '/keys', builder: (_, __) => KeysScreen()),
    GoRoute(path: '/settings', builder: (_, __) => SettingsScreen()),
  ],
);
```

---

## 6. datamodel (Freezed)

### Decision
**freezed + json_serializable** 。

### Rationale
- tabclassautomaticgenerate
- copyWith automaticgenerate
- JSON support
- patternsupport

### Key Patterns

```dart
@freezed
class Connection with _$Connection {
  const factory Connection({
    required String id,
    required String name,
    required String host,
    @Default(22) int port,
    required String username,
    required AuthMethod authMethod,
    String? keyId,
  }) = _Connection;

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);
}
```

---

## 7. dependencypackagelist

### Core
| package | version | purpose |
|-----------|-----------|------|
| dartssh2 | ^2.13.0 | SSH connection |
| xterm | ^4.0.0 | terminal |
| flutter_riverpod | ^2.5.0 | statemanagement |
| riverpod_annotation | ^2.3.0 | Riverpod codegen |
| go_router | ^14.0.0 | routing |

### Storage
| package | version | purpose |
|-----------|-----------|------|
| flutter_secure_storage | ^9.2.0 | encryptedstorage |
| shared_preferences | ^2.3.0 | settingssave |

### Model/Codegen
| package | version | purpose |
|-----------|-----------|------|
| freezed | ^2.5.0 | tabmodel |
| json_serializable | ^6.8.0 | JSON |
| freezed_annotation | ^2.4.0 | Freezed  |

### Testing
| package | version | purpose |
|-----------|-----------|------|
| flutter_test | (SDK) | widgettest |
| mockito | ^5.4.0 | mockgenerate |
| build_runner | ^2.4.0 | codegenerate |

---

## 8. Constitution Check (Post-Research)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | Dart strict mode + Freezed |
| II. KISS & YAGNI | ✅ PASS | existingfeature |
| III. Test-First | ✅ PASS | mockito + flutter_test |
| IV. Security-First | ✅ PASS | flutter_secure_storage + biometric |
| V. SOLID | ✅ PASS | Riverpod DI + service |
| VI. DRY | ✅ PASS | Freezed codegen |
| Prohibited Naming | ✅ PASS | main |

---

## References

- [dartssh2 - pub.dev](https://pub.dev/packages/dartssh2)
- [xterm.dart - pub.dev](https://pub.dev/packages/xterm)
- [Riverpod documentation](https://riverpod.dev/docs/)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [go_router](https://pub.dev/packages/go_router)
- [freezed](https://pub.dev/packages/freezed)



