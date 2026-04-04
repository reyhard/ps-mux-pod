# Data Model: Flutter Migration

**Feature**: 001-flutter-migration
**Date**: 2026-01-11

## Entity Overview

```
┌─────────────┐     ┌───────────┐     ┌─────────────┐
│ Connection  │────▷│  SSHKey   │     │ AppSettings │
└──────┬──────┘     └───────────┘     └─────────────┘
       │
       │ 1:N (runtime)
       ▼
┌─────────────┐
│ TmuxSession │
└──────┬──────┘
       │ 1:N
       ▼
┌─────────────┐
│ TmuxWindow  │
└──────┬──────┘
       │ 1:N
       ▼
┌─────────────┐     ┌──────────────────┐
│  TmuxPane   │◁────│ NotificationRule │
└─────────────┘     └──────────────────┘
```

---

## 1. Connection

SSH connection settings。

```dart
@freezed
class Connection with _$Connection {
  const factory Connection({
    required String id,              // UUID
    required String name,            // display (e.g., "Production AWS")
    required String host,            // host name or IP
    @Default(22) int port,           // SSHport
    required String username,        // SSHuser
    required AuthMethod authMethod,  // authentication
    String? keyId,                   // SSHkeyID（keyauthentication）
    @Default(30) int timeout,        // connection timeout
    @Default(60) int keepAliveInterval, // Keepalive
    String? icon,                    // custom
    String? color,                   // color（hex）
    @Default([]) List<String> tags,  // 
    DateTime? lastConnected,         // finalconnection
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Connection;

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);
}

@freezed
class AuthMethod with _$AuthMethod {
  const factory AuthMethod.password() = PasswordAuth;
  const factory AuthMethod.key() = KeyAuth;
}
```

### Validation Rules
- `name`: 1-50characters、
- `host`: enabledhost name/IPv4/IPv6
- `port`: 1-65535
- `username`: 1-32characters
- `timeout`: 5-120
- `keepAliveInterval`: 0（disabled） 10-300

### Storage
- ****: SharedPreferences (JSON)
- **password**: flutter_secure_storage (encrypted)

---

## 2. SSHKey

SSHkey。

```dart
@freezed
class SSHKey with _$SSHKey {
  const factory SSHKey({
    required String id,              // UUID
    required String name,            // display
    required KeyType type,           // key
    int? bits,                       // RSAwhen: 2048, 4096
    required String fingerprint,     // SHA256fingerprint
    required String publicKey,       // public key（displayport）
    @Default(false) bool encrypted,  // passphraseprotection
    @Default(false) bool isDefault,  // defaultkey
    required DateTime createdAt,
    DateTime? lastUsed,
  }) = _SSHKey;

  factory SSHKey.fromJson(Map<String, dynamic> json) =>
      _$SSHKeyFromJson(json);
}

enum KeyType { rsa, ed25519, ecdsa }
```

### Validation Rules
- `name`: 1-50characters
- `bits` (RSA): 2048, 3072, 4096
- `fingerprint`: SHA256:... format

### Storage
- **data**: SharedPreferences (JSON)
- **private key**: flutter_secure_storage (encrypted、key: `ssh_private_key_${id}`)

---

## 3. TmuxSession

servertmux session（）。

```dart
@freezed
class TmuxSession with _$TmuxSession {
  const factory TmuxSession({
    required String name,            // session
    required DateTime created,       // create
    required bool attached,          // attachstate
    required int windowCount,        // windowcount
    @Default([]) List<TmuxWindow> windows, // windowlist
  }) = _TmuxSession;
}
```

### State Transitions
```
[Not Exists] ──create──▷ [Detached] ◁──detach── [Attached]
                              │                      ▲
                              └───────attach─────────┘
                              │
                           kill-session
                              │
                              ▼
                        [Not Exists]
```

---

## 4. TmuxWindow

tmux window（）。

```dart
@freezed
class TmuxWindow with _$TmuxWindow {
  const factory TmuxWindow({
    required int index,              // window
    required String name,            // window
    required bool active,            // active state
    required int paneCount,          // panecount
    @Default([]) List<TmuxPane> panes, // panelist
  }) = _TmuxWindow;
}
```

---

## 5. TmuxPane

tmux pane（）。

```dart
@freezed
class TmuxPane with _$TmuxPane {
  const factory TmuxPane({
    required int index,              // pane
    required String id,              // paneID (%0, %1, etc.)
    required bool active,            // active state
    required String currentCommand,  // runin progresscommand
    required String title,           // pane
    required int width,              // width（columns）
    required int height,             // height（rows）
    required int cursorX,            // X
    required int cursorY,            // Y
  }) = _TmuxPane;
}
```

---

## 6. NotificationRule

Notification Rules。

```dart
@freezed
class NotificationRule with _$NotificationRule {
  const factory NotificationRule({
    required String id,              // UUID
    required String name,            // rule
    @Default(true) bool enabled,     // enabled/disabled

    // 
    required String connectionId,    // targetconnection
    String? sessionName,             // targetsession（null=all）
    int? windowIndex,                // targetwindow
    int? paneIndex,                  // targetpane

    // conditions
    required NotificationCondition condition,

    // 
    @Default(NotificationAction.inApp) NotificationAction action,
    String? soundName,               // （sound）

    // 
    @Default(NotificationFrequency.always) NotificationFrequency frequency,
    @Default(5000) int throttleMs,   // minimumnotification

    DateTime? lastTriggered,
    required DateTime createdAt,
  }) = _NotificationRule;

  factory NotificationRule.fromJson(Map<String, dynamic> json) =>
      _$NotificationRuleFromJson(json);
}

@freezed
class NotificationCondition with _$NotificationCondition {
  const factory NotificationCondition.text({
    required String text,
    @Default(false) bool caseSensitive,
  }) = TextCondition;

  const factory NotificationCondition.regex({
    required String pattern,
    @Default('') String flags,
  }) = RegexCondition;

  const factory NotificationCondition.idle({
    required int durationMs,
  }) = IdleCondition;

  const factory NotificationCondition.activity() = ActivityCondition;

  factory NotificationCondition.fromJson(Map<String, dynamic> json) =>
      _$NotificationConditionFromJson(json);
}

enum NotificationAction { inApp, sound, vibrate }
enum NotificationFrequency { always, oncePerSession, oncePerMatch }
```

### Validation Rules
- `name`: 1-50characters
- `throttleMs`: 1000-60000ms
- `pattern` (regex): enabled

### Storage
- SharedPreferences (JSON)

---

## 7. AppSettings

appsettings。

```dart
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(DisplaySettings()) DisplaySettings display,
    @Default(TerminalSettings()) TerminalSettings terminal,
    @Default(SshSettings()) SshSettings ssh,
    @Default(SecuritySettings()) SecuritySettings security,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

@freezed
class DisplaySettings with _$DisplaySettings {
  const factory DisplaySettings({
    @Default(14) int fontSize,       // 10-24
    @Default(FontFamily.jetBrainsMono) FontFamily fontFamily,
    @Default(ColorTheme.dracula) ColorTheme colorTheme,
    TerminalColors? customColors,
  }) = _DisplaySettings;

  factory DisplaySettings.fromJson(Map<String, dynamic> json) =>
      _$DisplaySettingsFromJson(json);
}

@freezed
class TerminalSettings with _$TerminalSettings {
  const factory TerminalSettings({
    @Default(2000) int scrollbackLimit, // 1000-10000
    @Default(false) bool bellSound,
    @Default(true) bool bellVibrate,
  }) = _TerminalSettings;

  factory TerminalSettings.fromJson(Map<String, dynamic> json) =>
      _$TerminalSettingsFromJson(json);
}

@freezed
class SshSettings with _$SshSettings {
  const factory SshSettings({
    @Default(60) int keepAliveInterval, // 0=off, 10-300
    @Default(false) bool compressionEnabled,
    @Default(22) int defaultPort,
    @Default('') String defaultUsername,
  }) = _SshSettings;

  factory SshSettings.fromJson(Map<String, dynamic> json) =>
      _$SshSettingsFromJson(json);
}

@freezed
class SecuritySettings with _$SecuritySettings {
  const factory SecuritySettings({
    @Default(true) bool useSecureEnclave,
    @Default(false) bool lockOnBackground,
    @Default(false) bool biometricUnlock,
  }) = _SecuritySettings;

  factory SecuritySettings.fromJson(Map<String, dynamic> json) =>
      _$SecuritySettingsFromJson(json);
}

enum FontFamily { jetBrainsMono, firaCode, meslo, hackGen, plemolJP }
enum ColorTheme { dracula, solarized, monokai, nord, custom }
```

---

## 8. TerminalColors

terminalcolor theme。

```dart
@freezed
class TerminalColors with _$TerminalColors {
  const factory TerminalColors({
    required String background,      // hex (#RRGGBB)
    required String foreground,
    required String cursor,
    required String selection,
    required String black,
    required String red,
    required String green,
    required String yellow,
    required String blue,
    required String magenta,
    required String cyan,
    required String white,
    required String brightBlack,
    required String brightRed,
    required String brightGreen,
    required String brightYellow,
    required String brightBlue,
    required String brightMagenta,
    required String brightCyan,
    required String brightWhite,
  }) = _TerminalColors;

  factory TerminalColors.fromJson(Map<String, dynamic> json) =>
      _$TerminalColorsFromJson(json);
}
```

---

## Storage Summary

| Entity | Storage | Key Pattern |
|--------|---------|-------------|
| Connection (metadata) | SharedPreferences | `connections` (JSON array) |
| Connection (password) | flutter_secure_storage | `password_${connectionId}` |
| SSHKey (metadata) | SharedPreferences | `ssh_keys` (JSON array) |
| SSHKey (private key) | flutter_secure_storage | `ssh_private_key_${keyId}` |
| NotificationRule | SharedPreferences | `notification_rules` (JSON array) |
| AppSettings | SharedPreferences | `app_settings` (JSON object) |
| TmuxSession/Window/Pane | Memory only | - |

---

## Code Generation Commands

```bash
# Freezed/JSON Serializable generate
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch
```



