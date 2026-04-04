# Feature Specification: SSH Reconnection

**Feature Branch**: `002-ssh-reconnect`
**Created**: 2026-01-10
**Status**: Draft
**Input**: User description: "Network reconnect feature. SSH disconnect detection, reconnect confirmation dialog, auto-reconnect option, and connection status indicator."

## Overview

MuxPod should help users quickly understand when an SSH connection drops and reconnect smoothly. In mobile environments, unstable networking such as Wi-Fi switching, signal changes, and wake-from-sleep events happens often, so seamless recovery improves the experience.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Always Check Connection Status (Priority: P1)

As a user, I want to always know the current SSH connection state so I can notice disruptions immediately and respond appropriately.

**Why this priority**: Connection visibility is the foundation for every reconnect feature. If users cannot see the state, they may not even realize there is a problem.

**Independent Test**: Verify that the terminal screen shows a connection status indicator and that it updates immediately when the state changes.

**Acceptance Scenarios**:

1. **Given** the user is connected over SSH and viewing the terminal, **When** the connection is healthy, **Then** the indicator shows `Connected`, such as with a green dot
2. **Given** the user is connected over SSH and viewing the terminal, **When** the connection is lost because of a network interruption, **Then** the indicator changes to `Disconnected` within 3 seconds
3. **Given** the indicator shows `Disconnected`, **When** the user taps it, **Then** detailed connection information is shown, including the disconnect reason and time

---

### User Story 2 - Confirm Reconnect on Disconnect (Priority: P2)

As a user, I want a confirmation dialog when SSH disconnects so I can decide whether to reconnect. That lets me recover quickly from accidental disconnects while skipping reconnect when I intentionally disconnected.

**Why this priority**: Manual reconnect is the most basic recovery path and is required when auto-reconnect is off or the user wants to confirm first.

**Independent Test**: Simulate a disconnect, verify that the dialog appears, and confirm that the user choice triggers either reconnect or navigation back to the connection screen.

**Acceptance Scenarios**:

1. **Given** the user is connected over SSH and viewing the terminal, **When** the SSH connection is unexpectedly lost, **Then** the reconnect confirmation dialog appears within 5 seconds
2. **Given** the reconnect confirmation dialog is visible, **When** the user selects `Reconnect`, **Then** the app retries with the same connection settings and returns to the terminal on success
3. **Given** the reconnect confirmation dialog is visible, **When** the user selects `Cancel`, **Then** the dialog closes and the app navigates to the connection list
4. **Given** the reconnect confirmation dialog is visible, **When** reconnect is in progress, **Then** the dialog shows progress such as `Connecting...`
5. **Given** reconnect is in progress, **When** reconnect fails, **Then** an error message and `Retry` / `Cancel` choices are shown

---

### User Story 3 - Auto-Reconnect Setting (Priority: P3)

As a user, I want an option to automatically reconnect when the connection drops so temporary network issues can recover without manual action.

**Why this priority**: Auto-reconnect is a convenience feature and can be built on top of manual reconnect once that exists.

**Independent Test**: Enable auto-reconnect, simulate a disconnect, and verify that reconnect happens without user interaction.

**Acceptance Scenarios**:

1. **Given** the connection settings screen is open, **When** the user checks the auto-reconnect option, **Then** an ON/OFF toggle is shown and the current value is clear
2. **Given** a connection with auto-reconnect enabled is open in the terminal, **When** the SSH connection drops unexpectedly, **Then** reconnect starts automatically without a confirmation dialog
3. **Given** auto-reconnect is in progress, **When** reconnecting, **Then** the status indicator shows `Reconnecting` and displays the attempt count
4. **Given** auto-reconnect has failed 3 times in a row, **When** the final attempt fails, **Then** automatic reconnect stops and the manual reconnect dialog appears
5. **Given** auto-reconnect is in progress, **When** the user cancels, **Then** auto-reconnect stops and the app navigates to the connection list

---

### Edge Cases

- What happens if reconnect is attempted before the network itself has recovered?
  - Treat it as a reconnect failure and show a message such as `Please check your network connection`
- What happens if the app moves to the background during reconnect?
  - Continue the reconnect process and notify the user of success or failure
- Should behavior differ between a server-side shutdown and a network failure?
  - Error messages should vary by disconnect reason, but reconnect options should still be offered
- What happens if credentials such as a password are not stored?
  - Show a password entry dialog before retrying reconnect
- What happens if multiple connections drop at once?
  - Only show the active connection dialog; other connections can be checked in the connection list

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system must notify the user within 3 seconds after an SSH disconnect is detected
- **FR-002**: The system must visually display connection status, including connected, disconnected, connecting, reconnecting, and error
- **FR-003**: The system must show a reconnect confirmation dialog when the connection drops
- **FR-004**: The user must be able to choose reconnect or cancel from the reconnect dialog
- **FR-005**: The user must be able to enable or disable auto-reconnect for each connection
- **FR-006**: The system must attempt reconnect without showing a dialog when auto-reconnect is enabled
- **FR-007**: The system must switch to manual confirmation after the auto-reconnect retry limit is exceeded, defaulting to 3 attempts
- **FR-008**: The system must show reconnect progress to the user
- **FR-009**: The system must show a clear error message when reconnect fails
- **FR-010**: The user must be able to cancel reconnect while it is in progress
- **FR-011**: The system must show detailed information when the user taps the status indicator
- **FR-012**: The system must prompt for credentials before reconnecting if credentials are not stored

### Key Entities

- **ConnectionStatus**: Represents the current connection state. Includes the status value (`connected`, `disconnected`, `connecting`, `reconnecting`, `error`), last updated time, and error details when applicable
- **ReconnectSettings**: Per-connection reconnect behavior settings. Includes the auto-reconnect flag, maximum retry count, and retry interval
- **ReconnectAttempt**: Records reconnect attempts, including attempt count, start time, and each attempt result

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can start reconnecting within 5 seconds of a disconnect
- **SC-002**: When auto-reconnect is enabled, the app can recover automatically from temporary network issues that resolve within 10 seconds with 95% success
- **SC-003**: The user can visually confirm the current connection state within 1 second
- **SC-004**: The reconnect dialog choices can be completed within 2 taps
- **SC-005**: The reconnect failure message helps the user understand the next action, such as checking the network or re-entering the password

## Assumptions

- SSH keep-alive already exists and can be used for disconnect detection
- Credentials such as passwords or SSH keys are securely stored and can be retrieved during reconnect
- Mobile background processing limits should be considered, but reconnect while the app is foregrounded takes priority
- The default reconnect retry interval is 5 seconds, and exponential backoff is not part of the initial implementation

## Out of Scope

- Server-side configuration changes such as `sshd` settings
- Special handling for VPN-based connections
- Simultaneous reconnect for multiple connections, limited to the active connection only
- Persistence or statistics for reconnect history
