# Feature Specification: MuxPod Phase 1 MVP

**Feature Branch**: `001-phase1-mvp`
**Created**: 2026-01-10
**Status**: Draft
**Input**: MuxPod Phase 1 MVP - includes the SSH connection foundation, connection management UI, basic tmux operations, terminal display, and key input features

## Overview

MuxPod is an Expo (React Native) application that lets users view and control tmux sessions, windows, and panes on a remote server from an Android smartphone over SSH. Phase 1 MVP implements the SSH connection foundation, connection management UI, basic tmux operations, terminal display, and key input features.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Establish SSH Connection (Priority: P1)

The user can establish an SSH connection to a remote server and access tmux sessions. They enter server information (host, port, username) and credentials (password or SSH key) to start the connection.

**Why this priority**: SSH connection is the core feature of the app. Without it, none of the other features work. If the user cannot connect to the server, tmux operations and terminal display are impossible.

**Independent Test**: Enter server information, tap Connect, and verify that the connection is established and the tmux session list is displayed.

**Acceptance Scenarios**:

1. **Given** the user is on the connection list screen, **When** they add a new connection, enter server information and a password, and tap Connect, **Then** the SSH connection is established and the app navigates to the tmux session list screen
2. **Given** an existing connection setting, **When** the user taps that connection card, **Then** the connection starts using the saved credentials
3. **Given** invalid credentials are entered, **When** the user taps Connect, **Then** an error message is shown and the user can try again

---

### User Story 2 - Connection Management (Priority: P1)

The user can add, edit, and delete multiple server connection settings. Each connection can be configured with a display name, host, port, username, and authentication method.

**Why this priority**: Connection management is as important as SSH connection. If the user cannot save and manage connection information, they must enter it manually every time, which greatly reduces usefulness.

**Independent Test**: Add, edit, and delete connections, then verify that the settings remain after restarting the app.

**Acceptance Scenarios**:

1. **Given** the connection list screen, **When** the user taps the + button, enters connection information, and saves it, **Then** the new connection is added to the list
2. **Given** an existing connection, **When** the user long-presses the connection card and chooses Edit, **Then** the connection edit screen appears and changes can be saved
3. **Given** an existing connection, **When** the user long-presses the connection card and chooses Delete, confirms, **Then** the connection is removed from the list
4. **Given** a connection setting has been added, **When** the app is closed and reopened, **Then** the saved connection setting is restored

---

### User Story 3 - tmux Session, Window, and Pane Navigation (Priority: P2)

The user can browse the hierarchy of tmux sessions, windows, and panes on the connected server and select any pane to display it.

**Why this priority**: tmux operations are needed after the SSH connection is established. Without navigating sessions, windows, and panes, the user cannot access a specific pane.

**Independent Test**: After connecting, the session list appears and the user can drill down from session to window to pane and select the desired pane.

**Acceptance Scenarios**:

1. **Given** the SSH connection is established, **When** the user taps the session tab on the terminal screen, **Then** the list of available tmux sessions is shown
2. **Given** the session list is shown, **When** the user selects a session, **Then** the session's window list is shown
3. **Given** a window is selected, **When** the user uses the pane selector, **Then** multiple panes can be chosen if they exist, and a single pane is auto-selected

---

### User Story 4 - Terminal Display (Priority: P2)

The user can view the contents of the selected pane in an ANSI color-capable terminal view. Japanese characters are also displayed correctly.

**Why this priority**: If the pane contents are not visible, remote operation has no value. Terminal display is closely tied to tmux navigation.

**Independent Test**: After selecting a pane, verify that terminal output is rendered correctly with ANSI colors and that Japanese text displays without corruption.

**Acceptance Scenarios**:

1. **Given** a pane is selected, **When** the terminal screen is shown, **Then** the pane's current contents are shown in real time
2. **Given** output in the pane contains ANSI color codes, **When** the terminal screen is shown, **Then** it is displayed with the correct colors
3. **Given** the pane contains Japanese text, **When** the terminal screen is shown, **Then** the Japanese text is displayed correctly
4. **Given** the terminal screen is visible, **When** a command runs remotely, **Then** the output updates in real time

---

### User Story 5 - Key Input (Priority: P2)

The user can type characters or special keys from the software keyboard or special key bar, including Enter, Tab, ESC, arrow keys, and Ctrl+key combinations, and send them to the selected pane.

**Why this priority**: Without input, the app would be view-only and half as valuable as a remote operation tool. Combined with terminal display, it enables two-way interaction.

**Independent Test**: Type characters from the keyboard and send Enter or Ctrl+C from the special key bar, then verify that the remote pane reflects the input.

**Acceptance Scenarios**:

1. **Given** a pane is selected, **When** the user types text and sends Enter, **Then** the command runs in the remote pane
2. **Given** a pane is selected, **When** the user taps ESC on the special key bar, **Then** the ESC key is sent to the pane
3. **Given** a pane is selected, **When** the user sends Ctrl+C, **Then** the running process is interrupted
4. **Given** a pane is selected, **When** the user sends arrow keys, **Then** cursor movement and history navigation work

---

### Edge Cases

- If the network disconnects during an SSH session, notify the user and present a reconnect option
- If tmux is not installed on the server, show an error message
- If no tmux session exists, show a message that prompts the user to create one
- Correctly handle wrapping for very long lines that exceed the screen width
- Keep up with fast output such as log streaming
- Show an appropriate error message when the SSH connection times out

## Requirements *(mandatory)*

### Functional Requirements

#### SSH Connection Foundation

- **FR-001**: The system must be able to establish SSH connections with password authentication
- **FR-002**: The system must be able to establish SSH connections with SSH key authentication (ed25519, RSA, ECDSA)
- **FR-003**: The system must support SSH connections on custom ports (1-65535)
- **FR-004**: The system must allow the connection timeout to be configured (default 30 seconds)
- **FR-005**: The system must allow the KeepAlive interval to be configured and support connection maintenance

#### Connection Management

- **FR-006**: The user must be able to create new SSH connection settings
- **FR-007**: The user must be able to edit existing connection settings
- **FR-008**: The user must be able to delete existing connection settings
- **FR-009**: Connection settings must be persisted in local storage
- **FR-010**: Passwords must be saved in encrypted secure storage
- **FR-011**: The connection list must be sortable by last connection time

#### tmux Operations

- **FR-012**: The system must be able to retrieve the tmux session list on the server
- **FR-013**: The system must be able to retrieve the window list for each session
- **FR-014**: The system must be able to retrieve the pane list for each window
- **FR-015**: The system must be able to capture the contents of a specified pane
- **FR-016**: The system must be able to send key input to a specified pane

#### Terminal Display

- **FR-017**: The system must be able to parse and display ANSI color codes (16 colors, 256 colors)
- **FR-018**: The system must be able to display Japanese text (full-width characters) correctly
- **FR-019**: The system must support scrollback history display
- **FR-020**: The system must poll pane contents and update them in real time every 100 ms

#### Key Input

- **FR-021**: The user must be able to input regular text characters
- **FR-022**: The user must be able to send Enter, Tab, Backspace, and ESC keys
- **FR-023**: The user must be able to send arrow keys (up, down, left, right)
- **FR-024**: The user must be able to send Ctrl+key combinations

### Key Entities

- **Connection**: Represents an SSH connection setting. It stores the host, port, username, authentication method, and display name, plus connection history and customization data.
- **TmuxSession**: Represents a tmux session. It stores the session name, creation time, attached state, and a list of associated windows.
- **TmuxWindow**: Represents a tmux window. It stores the index, window name, active state, and a list of associated panes.
- **TmuxPane**: Represents a tmux pane. It stores the index, ID, active state, current command, size, and cursor position.
- **PaneContent**: Represents the displayed content of a pane. It stores per-line text, scrollback size, and cursor position.

## Assumptions

- tmux is installed on the target server and the server is reachable over SSH
- The user has the credentials needed for SSH access, either a password or a private key
- Terminal size is assumed to be a standard smartphone-friendly size such as 80x24
- Network latency is assumed to be typical for mobile environments such as 4G or Wi-Fi
- Phase 1 does not include SSH key generation or Secure Enclave integration; those are handled in Phase 2
- Phase 1 does not include notifications; those are handled in Phase 2

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can complete the flow from creating a new connection setting to the first successful connection within 2 minutes
- **SC-002**: The flow from establishing the SSH connection to showing the tmux session list completes within 5 seconds
- **SC-003**: The flow from selecting a pane to displaying terminal contents completes within 1 second
- **SC-004**: Terminal update latency is 200 ms or less, providing a near-real-time experience
- **SC-005**: Input-to-screen reflection completes within 300 ms
- **SC-006**: Navigation remains smooth even with more than 10 sessions and 10 windows per session
- **SC-007**: Scroll operations remain smooth at 60 fps even with 1,000 lines of scrollback history
- **SC-008**: App startup remains within 3 seconds even with 5 or more saved connection settings



