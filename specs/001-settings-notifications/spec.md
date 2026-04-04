# Feature Specification: Settings and Notifications Implementation

**Feature Branch**: `001-settings-notifications`
**Created**: 2026-01-11
**Status**: Draft
**Input**: Implement settings and notifications. Resolve the TODO comments in `settings_screen.dart` and implement rule persistence in `notification_rules_screen`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Terminal Font Configuration (Priority: P1)

The user wants to change the terminal font size and font family to improve readability.

**Why this priority**: Visibility is critical for terminal work. Customization to match the user's environment and preferences is a core feature.

**Independent Test**: Change the font size in the settings screen and verify that the setting persists after restarting the app.

**Acceptance Scenarios**:

1. **Given** the settings screen is open, **When** Font Size is tapped, **Then** the font size picker dialog is shown
2. **Given** the font size dialog is shown, **When** a size is selected and confirmed, **Then** the setting is saved and reflected on screen
3. **Given** the settings screen is open, **When** Font Family is tapped, **Then** the font family picker dialog is shown
4. **Given** the font family dialog is shown, **When** a font is selected and confirmed, **Then** the setting is saved and reflected on screen

---

### User Story 2 - Notification Rule Management (Priority: P1)

The user wants to create and save pattern-matching notification rules for terminal output so important events are not missed.

**Why this priority**: Notifications are a differentiator for MuxPod and a core feature for remote server monitoring.

**Independent Test**: Create a new notification rule and verify that it persists after restarting the app.

**Acceptance Scenarios**:

1. **Given** the notification rules screen is open, **When** FAB is tapped, **Then** the rule creation dialog is shown
2. **Given** the form is filled out in the rule creation dialog, **When** Save is tapped, **Then** the rule is saved and shown in the list
3. **Given** one or more rules already exist, **When** the screen is opened, **Then** the saved rules are shown in the list
4. **Given** the rule list is shown, **When** a rule is tapped, **Then** the edit dialog is shown
5. **Given** the rule list is shown, **When** a rule is swiped left, **Then** the rule is deleted after confirmation

---

### User Story 3 - Behavior Settings Persistence (Priority: P2)

The user wants to change behavioral settings such as Haptic Feedback and Keep Screen On to match their preferences.

**Why this priority**: These settings directly affect UX, but the app remains usable with defaults.

**Independent Test**: Turn off Haptic Feedback and verify that it remains off after restarting the app.

**Acceptance Scenarios**:

1. **Given** the settings screen is open, **When** the Haptic Feedback toggle is changed, **Then** the setting is saved immediately
2. **Given** the settings screen is open, **When** the Keep Screen On toggle is changed, **Then** the setting is saved immediately
3. **Given** the settings were changed, **When** the app is restarted, **Then** the changes are preserved

---

### User Story 4 - Theme Selection (Priority: P2)

The user wants to change the app theme (dark/light) to match personal preference and environment.

**Why this priority**: This affects visibility and UX, but the default dark theme works for many users.

**Independent Test**: Change the theme to light and verify that the entire app switches accordingly.

**Acceptance Scenarios**:

1. **Given** the settings screen is open, **When** Theme is tapped, **Then** the theme picker dialog is shown
2. **Given** the theme picker dialog is shown, **When** a theme is selected and confirmed, **Then** the entire app theme switches immediately

---

### User Story 5 - External Links (Priority: P3)

The user wants to tap the app's source code link and open the GitHub repository in an external browser.

**Why this priority**: This is a supporting feature, not a core one.

**Independent Test**: Tap Source Code and verify that GitHub opens in an external browser.

**Acceptance Scenarios**:

1. **Given** the About section of the settings screen is shown, **When** Source Code is tapped, **Then** the GitHub repository opens in an external browser

---

### Edge Cases

- Does the terminal display remain correct when the font size is extremely small or large?
- Does validation work when an invalid regular-expression pattern is entered?
- Is error handling appropriate when a notification rule name or pattern is empty?
- Is list rendering performance acceptable when many rules exist (50+ items)?
- Is behavior appropriate when the GitHub link is tapped while offline?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system must allow font size changes from the settings screen (options: 10, 12, 14, 16, 18, 20 pt)
- **FR-002**: The system must allow font family changes from the settings screen (options: JetBrains Mono, Fira Code, Source Code Pro, Roboto Mono)
- **FR-003**: The system must persist the Haptic Feedback on/off setting
- **FR-004**: The system must persist the Keep Screen On on/off setting
- **FR-005**: The system must allow changing the theme (Dark/Light/System) from the settings screen
- **FR-006**: The system must open the URL in an external browser when Source Code is tapped
- **FR-007**: The system must support creating, editing, and deleting notification rules
- **FR-008**: The system must persist notification rules and retain them after app restarts
- **FR-009**: The system must validate regular-expression input in the notification rule form
- **FR-010**: The system must display a list of notification rules and allow each rule to be enabled or disabled

### Key Entities

- **AppSettings**: App-wide settings such as font size, font family, dark mode, vibration enabled, and keep-screen-on
- **NotificationRule**: Notification rules such as ID, name, pattern, regex flag, enabled flag, and vibration flag

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can change the font size or font family within three taps
- **SC-002**: Setting changes are saved immediately (within 1 second) and are retained 100% after app restarts
- **SC-003**: Creating a notification rule can be completed within 30 seconds
- **SC-004**: Even with a list of 50 rules, screen rendering takes no more than 2 seconds
- **SC-005**: Validation errors appear immediately for all form inputs

## Assumptions

- Font size options should use six steps in the 10-20 pt range, which is standard for the industry
- Font family options should be four common programming fonts
- Theme selection should include a System option that follows the OS setting
- The GitHub URL should use the current repository URL (`https://github.com/muxpod`)
- No maximum limit is set for notification rules; revisit if performance becomes an issue



