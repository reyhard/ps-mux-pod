# Quickstart: Settings and Notifications Implementation

**Feature**: 001-settings-notifications
**Date**: 2026-01-11

## Prerequisites

- Flutter 3.24+
- existingMuxPodprojectbuildpossiblestate

## Setup

### 1. dependenciesadd

```bash
flutter pub add url_launcher
```

### 2. runverify

```bash
flutter analyze
flutter test
flutter run
```

## Implementation Overview

### target for changesfile

| File | Changes |
|------|---------|
| `lib/main.dart` | MyAppConsumerWidgetchange、themedynamic |
| `lib/screens/settings/settings_screen.dart` | TODOcommentresolve（6） |
| `lib/screens/notifications/notification_rules_screen.dart` | rulesaveimplement、listdisplay |
| `lib/providers/settings_provider.dart` | themeModesupport（） |

### newcreatefile

| File | Purpose |
|------|---------|
| `lib/Widgets/dialogs/font_size_dialog.dart` | font sizeselect |
| `lib/Widgets/dialogs/font_family_dialog.dart` | font familyselect |
| `lib/Widgets/dialogs/theme_dialog.dart` | Theme Selection |

## Key Implementation Points

### 1. SettingsScreen TODOs

```dart
// Font Size Dialog (line 24)
onTap: () async {
  final size = await showDialog<double>(
    context: context,
    builder: (context) => FontSizeDialog(
      currentSize: ref.read(settingsProvider).fontSize,
    ),
  );
  if (size != null) {
    ref.read(settingsProvider.notifier).setFontSize(size);
  }
}

// Haptic Feedback Toggle (line 43)
value: ref.watch(settingsProvider).enableVibration,
onChanged: (value) {
  ref.read(settingsProvider.notifier).setEnableVibration(value);
}

// External URL (line 93)
onTap: () async {
  final uri = Uri.parse('https://github.com/muxpod');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

### 2. NotificationRulesScreen

```dart
// Watch notification rules
final state = ref.watch(notificationProvider);

// Build rule list
ListView.builder(
  itemCount: state.rules.length,
  itemBuilder: (context, index) {
    final rule = state.rules[index];
    return Dismissible(
      key: Key(rule.id),
      onDismissed: (_) => ref.read(notificationProvider.notifier).removeRule(rule.id),
      child: ListTile(
        title: Text(rule.name),
        subtitle: Text(rule.pattern),
        trailing: Switch(
          value: rule.enabled,
          onChanged: (_) => ref.read(notificationProvider.notifier).toggleRule(rule.id),
        ),
      ),
    );
  },
)

// Save rule in dialog
void _save() {
  if (_formKey.currentState!.validate()) {
    final rule = NotificationRule(
      id: Widget.ruleId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      pattern: _patternController.text,
      isRegex: _isRegex,
      vibrate: _vibrate,
    );
    if (Widget.ruleId != null) {
      ref.read(notificationProvider.notifier).updateRule(rule);
    } else {
      ref.read(notificationProvider.notifier).addRule(rule);
    }
    Navigator.pop(context);
  }
}
```

### 3. Dynamic Theme in main.dart

```dart
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'MuxPod',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

## Testing

### Run All Tests

```bash
flutter test
```

### Run Specific Test

```bash
flutter test test/screens/settings_screen_test.dart
flutter test test/screens/notification_rules_screen_test.dart
```

## Verification Checklist

- [ ] Font Sizechangesave、restartretain
- [ ] Font Familychangesave、restartretain
- [ ] Haptic Feedbacksave
- [ ] Keep Screen Onsave
- [ ] Themechangethe entire appreflect
- [ ] Source CodeGitHubexternal
- [ ] Notification Rulescreatesave
- [ ] Notification Ruleseditdelete
- [ ] ruleenabled/disabledswitchsave
- [ ] app restartruleretain

## Common Issues

### url_launcher not working

Android: `AndroidManifest.xml` intent-filteraddrequiredwhen

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

### SharedPreferences not persisting

testmockrequired:

```dart
SharedPreferences.setMockInitialValues({});
```



