# Research: Settings and Notifications

**Feature**: 001-settings-notifications
**Date**: 2026-01-11

## 1. Existing Implementation Analysis

### 1.1 Settings Provider (settings_provider.dart)

**Current state**:
- `AppSettings` classallsettingsretain
- `SettingsNotifier` SharedPreferencessave/loadimplement
- existingmethod: `setDarkMode()`, `setFontSize()`, `setFontFamily()`, `setEnableVibration()` 

**Decision**: existingSettingsNotifiermethodreuse
**Rationale**: requiredfeatureimplement
**Alternatives**: （reimplementnot needed）

### 1.2 Notification Provider (notification_provider.dart)

**Current state**:
- `NotificationState` statemanagement
- `NotificationNotifier` CRUDoperationimplement: `addRule()`, `removeRule()`, `updateRule()`, `toggleRule()`
- `NotificationEngine` persistprocessingimplement

**Decision**: existingNotificationNotifiermethodUI
**Rationale**: rulepersistfeature
**Alternatives**: 

### 1.3 Theme Management (app_theme.dart, main.dart)

**Current state**:
- `AppTheme.dark`  `AppTheme.light` （lightdarksame）
- `AppTheme.getThemeMode()` method
- `main.dart`  `ThemeMode.dark` code

**Decision**: `MyApp`ConsumerWidgetchange、settingsProviderthemeretrieve
**Rationale**: dynamicthemeswitchstatemanagementintegrationrequired
**Alternatives**:
- InheritedWidgetimplement → （Riverpodexisting）
- MaterialApp.router → （change）

## 2. UI Implementation Patterns

### 2.1 Dialog Implementation

**Decision**: FlutterAlertDialog + SimpleDialogOption
**Rationale**: Material Design、Flutterstandard
**Alternatives**:
- BottomSheet → （selectcount）
- custom → （KISS）

### 2.2 font sizeselect

**Decision**: RadioListTilelistAlertDialog
**select**: 10, 12, 14, 16, 18, 20pt（default14）
**Rationale**: codesettingsrange

### 2.3 font familyselect

**Decision**: RadioListTilelistAlertDialog
**select**: JetBrains Mono, Fira Code, Source Code Pro, Roboto Mono
**Rationale**: font4

### 2.4 Theme Selection

**Decision**: RadioListTilelistAlertDialog
**select**: Dark, Light, System
**Rationale**: app3pattern

## 3. External Links

### 3.1 Using url_launcher

**Decision**: url_launcherpackage
**Rationale**: Flutterrecommended、support
**Alternatives**:
- android_intent → Android
- webview → （URLstart）

**implement**:
```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

## 4. Notification Rules Screen Improvements

### 4.1 Rule List Display

**Decision**: `ref.watch(notificationProvider).rules` ListView.builderdisplay
**Rationale**: Riverpodstandardpattern

### 4.2 Swipe Delete

**Decision**: Dismissiblewidget
**Rationale**: Flutterstandard、userUX
**verify**: deleteverifydisplay

### 4.3 Rule Edit

**Decision**: existing_RuleFormDialogextension、ruleIdwheneditmode
**Rationale**: new/editsamereuse（DRY）

## 5. dependencies

### 5.1 Added Packages

| package | purpose | state |
|-----------|------|------|
| url_launcher | externalURLstart | addrequired |
| google_fonts | fontselect | existing |
| shared_preferences | settingssave | existing |

### 5.2 pubspec.yamlverify

```yaml
dependencies:
  url_launcher: ^6.2.0  # add
```

## 6. test

### 6.1 Widget Tests

- settings_screen_test.dart: display、settingschange
- notification_rules_screen_test.dart: rulelist、CRUDoperation

### 6.2 Mocks

- SharedPreferencesmock
- NotificationEnginemock

## Summary

- existingproviderfeature、new implementation is not needed
- The main implementation is calling provider methods from the UI layer
- The url_launcher package needs to be added
- A minor main.dart change is needed for theme switching



