# Feature Specification: Flutter Migration

**Feature Branch**: `001-flutter-migration`
**Created**: 2026-01-11
**Status**: Draft
**Input**: User description: "Migrate MuxPod to Flutter. Use `dartssh2` + `xterm.dart`. Refer to `docs/tmux-mobile-design-v2.md` and `docs/working/flutter-vs-rn-comparison.md`."

## Overview

Fully migrate MuxPod from React Native (Expo) to Flutter. Resolve the problems with the current `react-native-ssh-sftp` dependency, which has been unmaintained for 8 years, and adopt the actively maintained `dartssh2` + `xterm.dart` stack.

**Migration reasons**:
- `react-native-ssh-sftp` is unmaintained and was published to npm 8 years ago
- Android builds require many patches
- It does not support the New Architecture
- `dartssh2` is a pure Dart implementation with no native dependencies and is actively maintained

## User Scenarios & Testing

### User Story 1 - SSH Connection and Terminal Operation (Priority: P1)

The user can SSH into a remote server from an Android device and run commands inside a tmux pane.

**Why this priority**: This is the core app feature. Without it, the app provides no value.

**Independent Test**: Add a connection setting, connect to the server, run `ls` inside a tmux pane, and verify that the result appears.

**Acceptance Scenarios**:

1. **Given** a connection setting is saved, **When** the user taps the connection, **Then** an SSH connection is established and the tmux session list is shown
2. **Given** a tmux session exists, **When** the user selects a pane, **Then** the pane contents are displayed with ANSI color support
3. **Given** a pane is displayed, **When** the user enters a command, **Then** the key input is sent to the server and the result is shown
4. **Given** a connection is active, **When** the network disconnects, **Then** an error message is shown and a reconnect option is offered

---

### User Story 2 - Connection Management (Priority: P1)

The user can add, edit, delete, and manage multiple server connection settings.

**Why this priority**: This is a basic feature alongside terminal operations. Without connection settings, the user cannot connect.

**Independent Test**: Add a new connection, verify it appears in the list, and use it to connect.

**Acceptance Scenarios**:

1. **Given** the app launches, **When** the user taps Add, **Then** the connection settings form is shown
2. **Given** the connection form, **When** the user enters host, username, and authentication method and saves, **Then** the connection is added to the list
3. **Given** the connection list, **When** the user long-presses a connection, **Then** edit and delete options are shown
4. **Given** password authentication is selected, **When** the user enters a password, **Then** the password is encrypted and saved

---

### User Story 3 - SSH Key Management (Priority: P2)

The user can import or generate SSH keys and use them for server authentication.

**Why this priority**: The app works with password authentication, but key authentication is recommended for security.

**Independent Test**: Generate a key and use it to connect to the server.

**Acceptance Scenarios**:

1. **Given** the key management screen, **When** the user taps Generate, **Then** after choosing a key type (Ed25519/RSA), a key pair is generated
2. **Given** key generation is complete, **When** the public key is copied, **Then** it is copied to the clipboard
3. **Given** the key management screen, **When** a key is imported from a file, **Then** the private key is saved in secure storage
4. **Given** a connection setting, **When** the authentication method is set to Key, **Then** the user can choose from the saved key list

---

### User Story 4 - tmux Navigation (Priority: P2)

The user can navigate tmux sessions, windows, and panes hierarchically.

**Why this priority**: This is essential for users with multiple sessions and panes.

**Independent Test**: With multiple sessions available, the user can move between sessions, windows, and panes.

**Acceptance Scenarios**:

1. **Given** the connection is complete, **When** the session list is shown, **Then** all sessions are displayed with their names and creation times
2. **Given** a session is selected, **When** a window is tapped, **Then** that window's pane list is shown
3. **Given** a window with multiple panes, **When** a pane is selected, **Then** the selected pane's contents are shown
4. **Given** a pane is displayed, **When** the user swipes with a gesture, **Then** the app switches to the adjacent pane or window

---

### User Story 5 - Notification Rules (Priority: P3)

The user can set pattern-matching rules for terminal output and receive in-app notifications when they match.

**Why this priority**: This is useful, but not core functionality.

**Independent Test**: Set a text rule for "error" and verify that a notification fires when `error` appears in the terminal.

**Acceptance Scenarios**:

1. **Given** the notification rules screen, **When** a new rule is added, **Then** the user can configure a text or regular-expression pattern
2. **Given** a rule has been configured, **When** the pane output matches the pattern, **Then** an in-app notification is shown
3. **Given** a notification has been fired, **When** the notification is tapped, **Then** the app moves to the matching pane

---

### User Story 6 - Display Settings (Priority: P3)

The user can customize the terminal font, font size, and color theme.

**Why this priority**: This improves usability, but the app is usable with the default settings.

**Independent Test**: Change the font size and verify that it is reflected in the terminal display.

**Acceptance Scenarios**:

1. **Given** the settings screen, **When** the font size is changed, **Then** the terminal display updates immediately
2. **Given** the settings screen, **When** a color theme is selected, **Then** the terminal colors change
3. **Given** a Japanese font is selected, **When** the terminal is displayed, **Then** Japanese text is rendered correctly

---

### Edge Cases

- **Connection timeout**: If the SSH connection cannot be established within the configured time, show a clear error message
- **tmux not installed**: If tmux is not installed on the server, show an appropriate message
- **No sessions**: If no tmux session exists, present an option to create one
- **Network disconnect**: If the network disconnects during a connection, provide a reconnect feature
- **Heavy output**: The UI must not freeze even when output is very fast
- **Invalid key format**: Show an error when importing an unsupported key format

## Requirements

### Functional Requirements

- **FR-001**: The app must be able to establish SSH connections using `dartssh2`
- **FR-002**: The app must use `xterm.dart` for terminal display
- **FR-003**: The app must support both password authentication and public-key authentication
- **FR-004**: The app must be able to list and select tmux sessions, windows, and panes
- **FR-005**: The app must correctly render ANSI escape sequences (256 colors)
- **FR-006**: The app must correctly display Japanese text (CJK characters)
- **FR-007**: The app must be able to send special keys such as ESC, Ctrl+character, and arrow keys
- **FR-008**: The app must persist connection settings in local storage
- **FR-009**: The app must encrypt and save passwords and private keys
- **FR-010**: The app must be able to generate SSH keys (Ed25519/RSA)
- **FR-011**: The app must be able to import SSH keys from a file
- **FR-012**: The app must be able to configure notification rules for text and regular-expression matches
- **FR-013**: The app must fire in-app notifications when a match occurs
- **FR-014**: The app must be able to configure font size, font family, and color theme
- **FR-015**: The app must synchronize PTY size when the terminal size changes

### Key Entities

- **Connection**: SSH connection settings (host, port, username, authentication method, associated key)
- **SSHKey**: SSH key pair (type, fingerprint, public key, encrypted private key)
- **TmuxSession**: tmux session (name, creation time, window list)
- **TmuxWindow**: tmux window (index, name, pane list)
- **TmuxPane**: tmux pane (ID, index, size, cursor position)
- **NotificationRule**: Notification rule (pattern, target pane, action)
- **AppSettings**: App settings (display settings, terminal settings, SSH settings, security settings)

## Success Criteria

### Measurable Outcomes

- **SC-001**: The user can establish an SSH connection within 5 seconds under normal network conditions
- **SC-002**: Terminal input latency stays at 200 ms or less
- **SC-003**: ANSI colors (256 colors) render correctly, with a 100% pass rate for existing test cases
- **SC-004**: Japanese text displays correctly in the terminal with no garbling
- **SC-005**: The UI does not freeze even with output at 1,000 lines per second
- **SC-006**: The flow from adding a connection setting to completing a connection takes 3 taps or fewer
- **SC-007**: The app provides functionality equal to or better than the existing React Native implementation
- **SC-008**: The build succeeds without native patches

## Assumptions

- tmux is installed on the user's server
- The user has SSH-accessible credentials
- The target platform is Android only, with iOS and desktop considered in the future
- All features from the existing React Native implementation are in scope for migration
- Using the pure Dart `dartssh2` implementation removes native dependencies

## Out of Scope

- iOS support (future phase)
- Desktop support (future phase)
- MOSH support
- SFTP (file transfer)
- Port forwarding
- External push notifications (ntfy integration)



