# Implementation Plan: Flutter Migration

**Branch**: `001-flutter-migration` | **Date**: 2026-01-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-flutter-migration/spec.md`

## Summary

MuxPodReact Native (Expo)Fluttercompleteline。react-native-ssh-sftpissueresolve、Pure Dartimplementdartssh2 + xterm.dart、dependencybuildstable。

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.24+
**Primary Dependencies**: dartssh2 2.13+, xterm 4.0+, flutter_riverpod, flutter_secure_storage, shared_preferences
**Storage**: SharedPreferences (connection settings), flutter_secure_storage (private key/passwordencrypted)
**Testing**: flutter_test, mockito, integration_test
**Target Platform**: Android (API 21+) ※iOS/desktopfuturephase
**Project Type**: mobile
**Performance Goals**: SSH connection5、inputlatency200ms、1000line/UI
**Constraints**: build、ANSIcolor256colorsupport、CJKcharactersnormaldisplay
**Scale/Scope**: 6screen (connection list、terminal、keymanagement、Notification Rules、settings、connectionedit)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | Dart static、`analysis_options.yaml`  strict mode settingspossible |
| II. KISS & YAGNI | ✅ PASS | existingRNimplementfeature、newfeatureadd |
| III. Test-First (TDD) | ✅ PASS | flutter_test + mockito TDDpossible |
| IV. Security-First | ✅ PASS | flutter_secure_storage encryptedsave、biometricssupport |
| V. SOLID | ✅ PASS | Riverpod  DI、servicesupport |
| VI. DRY | ✅ PASS | sharedservice |
| Prohibited Naming | ✅ PASS | utils/, helpers/ 、main |

### Quality Gates Mapping (TypeScript → Dart)

| RN/TS Gate | Flutter/Dart Equivalent |
|------------|------------------------|
| `pnpm typecheck` | `dart analyze` |
| `pnpm lint` | `dart analyze` (lint rules in analysis_options.yaml) |
| newfeaturetest | `flutter test` |

### Post-Phase 1 Check (Design Validation)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | ✅ PASS | Freezedtabmodel、strict modesettings |
| II. KISS & YAGNI | ✅ PASS | existingRNfeature、 |
| III. Test-First (TDD) | ✅ PASS | contracts/interface、mockitomockpossible |
| IV. Security-First | ✅ PASS | flutter_secure_storageprivate keyencrypted、biometricssupport |
| V. SOLID | ✅ PASS | service、Riverpod DI、interface |
| VI. DRY | ✅ PASS | Freezed codegen、sharedWidget |
| Prohibited Naming | ✅ PASS | services/ssh/, services/tmux/main |

**Conclusion**: All Constitution gates passed. Ready for Phase 2 (tasks generation).

## Project Structure

### Documentation (this feature)

```text
specs/001-flutter-migration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
flutter/                     # newFlutter project
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── router/              # GoRouter routing
│   │   └── app_router.dart
│   ├── models/              # datamodel (Freezed)
│   │   ├── connection.dart
│   │   ├── ssh_key.dart
│   │   ├── tmux.dart
│   │   ├── notification_rule.dart
│   │   └── app_settings.dart
│   ├── providers/           # Riverpod provider
│   │   ├── connection_provider.dart
│   │   ├── ssh_provider.dart
│   │   ├── tmux_provider.dart
│   │   ├── terminal_provider.dart
│   │   ├── key_provider.dart
│   │   ├── notification_provider.dart
│   │   └── settings_provider.dart
│   ├── services/            # 
│   │   ├── ssh/
│   │   │   ├── ssh_client.dart
│   │   │   └── ssh_auth.dart
│   │   ├── tmux/
│   │   │   ├── tmux_commands.dart
│   │   │   └── tmux_parser.dart
│   │   ├── terminal/
│   │   │   └── terminal_controller.dart
│   │   ├── keychain/
│   │   │   └── secure_storage.dart
│   │   └── notification/
│   │       ├── notification_engine.dart
│   │       └── pattern_matcher.dart
│   ├── screens/             # screen Widget
│   │   ├── connections/
│   │   │   ├── connections_screen.dart
│   │   │   ├── connection_form_screen.dart
│   │   │   └── Widgets/
│   │   ├── terminal/
│   │   │   ├── terminal_screen.dart
│   │   │   └── Widgets/
│   │   ├── keys/
│   │   │   ├── keys_screen.dart
│   │   │   ├── key_generate_screen.dart
│   │   │   ├── key_import_screen.dart
│   │   │   └── Widgets/
│   │   ├── notifications/
│   │   │   └── notification_rules_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   ├── Widgets/             # shared Widget
│   │   ├── terminal_view.dart
│   │   ├── special_keys_bar.dart
│   │   └── session_tree.dart
│   └── theme/               # theme
│       ├── app_theme.dart
│       └── terminal_colors.dart
├── test/
│   ├── unit/
│   │   ├── services/
│   │   └── providers/
│   ├── Widget/
│   │   └── screens/
│   └── integration/
├── integration_test/
├── android/
├── pubspec.yaml
└── analysis_options.yaml
```

**Structure Decision**: mobileapp。lib/ main。existingRN src/  Flutter 、providers/ (Riverpod) statemanagement、services/ 、screens/ UI 。

## Complexity Tracking

> **No Constitution violations identified. This section can be removed or left empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | - | - |



