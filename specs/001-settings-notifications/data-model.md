# Data Model: Settings and Notifications

**Feature**: 001-settings-notifications
**Date**: 2026-01-11

## 1. Entities

### 1.1 AppSettings

appallsettingsretain。

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| darkMode | bool | true | modeenabled |
| fontSize | double | 14.0 | terminalfont size（pt） |
| fontFamily | String | "JetBrains Mono" | terminalfont family |
| requireBiometricAuth | bool | false | authenticationrequired |
| enableNotifications | bool | true | notificationenabled |
| enableVibration | bool | true | enabled |
| scrollbackLines | int | 10000 | scrollbackrows |

**Validation Rules**:
- fontSize: 10.0 <= value <= 20.0
- fontFamily: list ["JetBrains Mono", "Fira Code", "Source Code Pro", "Roboto Mono"]

**Storage**: SharedPreferences
- Key prefix: `settings_`
- eachseparatekeysave

### 1.2 NotificationRule

Notification Rules。

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| id | String | UUID | ruleseparate |
| name | String | required | ruledisplay |
| pattern | String | required | pattern |
| isRegex | bool | false |  |
| enabled | bool | true | ruleenabled |
| caseSensitive | bool | false | characterscharactersseparate |
| sound | String? | null | file |
| vibrate | bool | true | enabled |
| priority | NotificationPriority | normal | notificationpriority |
| targetSession | String? | null | targetsession（nullall） |
| rateLimitSeconds | int | 5 | samerulenotification（） |
| createdAt | DateTime | now | create |
| lastMatchedAt | DateTime? | null | final |

**Validation Rules**:
- name: 1characters
- pattern: 1characters、isRegex=truewhenenabled
- rateLimitSeconds: 0 <= value <= 3600

**Storage**: SharedPreferences
- Key: `notification_rules`
- Format: JSONcolumn

### 1.3 NotificationPriority (Enum)

notificationprioritycolumn。

| Value | Index | Description |
|-------|-------|-------------|
| low | 0 | low priority |
| normal | 1 | normal priority |
| high | 2 | high priority |
| urgent | 3 | urgent（high priority） |

### 1.4 ThemeMode (Flutterstandard)

thememodecolumn（Flutterstandard）。

| Value | Description |
|-------|-------------|
| system | settings |
| light | mode |
| dark | mode |

**Mapping**:
- AppSettings.darkMode = true → ThemeMode.dark
- AppSettings.darkMode = false → ThemeMode.light
- extension: darkMode  themeMode (String) changeconsider

## 2. State Classes

### 2.1 NotificationState

notificationproviderstateclass。

| Field | Type | Description |
|-------|------|-------------|
| rules | List\<NotificationRule\> | allrulelist |
| recentEvents | List\<NotificationEvent\> | notification |
| globalEnabled | bool | notificationenabled |
| isLoading | bool | loadin progress |
| error | String? | error message |

## 3. Relationships

```
┌──────────────────┐
│   AppSettings    │
│                  │
│  - fontSize      │
│  - fontFamily    │
│  - darkMode      │
│  - enableVibrate │
└──────────────────┘
         │
         │ references
         ▼
┌──────────────────┐
│ NotificationRule │
│                  │
│  - vibrate       │ ← AppSettings.enableVibration settings
│  - priority      │
│  - enabled       │
└──────────────────┘
         │
         │ generates
         ▼
┌──────────────────┐
│NotificationEvent │
│                  │
│  - rule          │
│  - matchResult   │
│  - timestamp     │
└──────────────────┘
```

## 4. State Transitions

### 4.1 NotificationRule Lifecycle

```
[Create] ──► [Enabled] ◄──► [Disabled]
                │
                ▼
           [Delete]
```

### 4.2 Settings Change Flow

```
User Action ──► Provider Method ──► SharedPreferences ──► State Update ──► UI Rebuild
```

## 5. Font Options

### 5.1 Available Font Sizes

| Value (pt) | Use Case |
|------------|----------|
| 10 | high-densitydisplay |
| 12 |  |
| 14 | standard（default） |
| 16 |  |
| 18 | larger |
| 20 | maximum |

### 5.2 Available Font Families

| Font | Package | Notes |
|------|---------|-------|
| JetBrains Mono | google_fonts | default、support |
| Fira Code | google_fonts | font |
| Source Code Pro | google_fonts | Adobe |
| Roboto Mono | google_fonts | Androidstandard |

## 6. Theme Options

| Option | ThemeMode | AppSettings.darkMode |
|--------|-----------|---------------------|
| Dark | ThemeMode.dark | true |
| Light | ThemeMode.light | false |
| System | ThemeMode.system | (extension) |

**Note**: Systemsupport AppSettings extension themeMode addrequired。initialimplement Dark/Light support。



