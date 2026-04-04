# Implementation Plan: Settings and Notifications

**Branch**: `001-settings-notifications` | **Date**: 2026-01-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-settings-notifications/spec.md`

## Summary

Resolve the TODO comments in the settings screen and fully implement notification rule management. Reuse the existing `settingsProvider` and `notificationProvider` to implement font size/family picker dialogs, persistence for behavioral settings, theme selection, and notification rule CRUD operations.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.24+
**Primary Dependencies**: flutter_riverpod, shared_preferences, flutter_local_notifications, url_launcher
**Storage**: SharedPreferences (settings), SharedPreferences (notification rules in JSON format)
**Testing**: flutter_test, mockito
**Target Platform**: Android (iOS support planned)
**Project Type**: Mobile
**Performance Goals**: Save setting changes within 1 second and render the list within 2 seconds for 50 rules
**Constraints**: No offline support required; local storage only
**Scale/Scope**: Single user, no limit on the number of rules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety | PASS | Strictly typed with Dart's type system |
| II. KISS & YAGNI | PASS | Reuse existing providers; no new abstractions |
| III. Test-First (TDD) | PASS | Create tests for each feature |
| IV. Security-First | PASS | No sensitive data in settings; SSH keys are managed separately |
| V. SOLID | PASS | SRP: settings and notifications are separated into different providers |
| VI. DRY | PASS | Reuse existing `AppSettings` and `NotificationRule` types |
| Prohibited Naming | PASS | Do not use utils/helpers; keep the screens/services structure |

**Gate Result**: PASS - all principles are satisfied

## Project Structure

### Documentation (this feature)

```text
specs/001-settings-notifications/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A for mobile-only)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── providers/
│   ├── settings_provider.dart    # existing - reuse
│   └── notification_provider.dart # existing - reuse
├── screens/
│   ├── settings/
│   │   └── settings_screen.dart  # target for changes
│   └── notifications/
│       └── notification_rules_screen.dart # target for changes
├── services/
│   └── notification/
│       └── notification_engine.dart # existing - reuse
├── theme/
│   └── app_theme.dart            # theme management
└── Widgets/
    └── dialogs/                  # new dialog Widgets

test/
├── providers/
│   ├── settings_provider_test.dart
│   └── notification_provider_test.dart
├── screens/
│   ├── settings_screen_test.dart
│   └── notification_rules_screen_test.dart
└── Widgets/
    └── dialogs_test.dart
```

**Structure Decision**: Single mobile project structure. Keep the existing Flutter standard structure.

## Complexity Tracking

> No violations - no additional complexity justification is needed



