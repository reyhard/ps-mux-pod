# Feature Specification: SSH/Terminal Integration

**Feature Branch**: `001-ssh-terminal-integration`
**Created**: 2026-01-11
**Status**: Draft
**Input**: User description: "Implement SSH/Terminal integration. Resolve the TODO comments in `terminal_screen.dart` (lines 39 and 287), and use the existing `lib/services/ssh/ssh_client.dart` and `lib/services/tmux/tmux_commands.dart` to complete the pipeline from SSH connection to tmux attach to key sending."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - terminal screenSSH connectionestablishment (Priority: P1)

When the user selects a server from the connection list and navigates to the terminal screen, the SSH connection is established automatically and the tmux session content is displayed.

**Why this priority**: This is the core app feature. Terminal operations are impossible without an SSH connection, so it has the highest priority.

**Independent Test**: When the terminal screen opens, verify that the SSH connection is established and the remote server's tmux session content is shown on screen.

**Acceptance Scenarios**:

1. **Given** a valid connection setting is saved, **When** the user taps that connection to open the terminal screen, **Then** the SSH connection is established and the tmux session list is retrieved
2. **Given** the SSH connection is established, **When** a tmux session exists, **Then** the app auto-attaches to the first session and displays terminal output
3. **Given** the SSH connection is established, **When** no tmux session exists, **Then** a new session is created and attached

---

### User Story 2 - Key Inputsend (Priority: P1)

When the user enters keys on the terminal screen, those keys are sent to the remote server's tmux session over SSH and the results are reflected on screen.

**Why this priority**: This is a basic terminal interaction feature. Connection alone is not enough to operate the app, so it is equally important.

**Independent Test**: Send keys through the special key bar and text input, then verify that they are reflected in the remote tmux session.

**Acceptance Scenarios**:

1. **Given** the user is attached to a tmux session, **When** the ESC button in the special key bar is pressed, **Then** the ESC key is sent over SSH
2. **Given** the user is attached to a tmux session, **When** the user enters a command from the text input dialog, **Then** the command string is sent over SSH and the result is displayed
3. **Given** the user is attached to a tmux session, **When** the user presses Ctrl+C, **Then** an interrupt signal is sent

---

### User Story 3 - terminal outputdisplay (Priority: P1)

Terminal output from the remote server is displayed in real time on the xterm screen. ANSI color codes are also interpreted correctly.

**Why this priority**: Without visible output, the terminal cannot function, so this has the highest priority.

**Independent Test**: Run a command remotely and verify that its output appears in real time on the local terminal screen.

**Acceptance Scenarios**:

1. **Given** the user is attached to a tmux session, **When** data arrives from the remote side, **Then** it is displayed in real time in the xterm Widget
2. **Given** the user is attached to a tmux session, **When** output containing ANSI color codes arrives, **Then** it is displayed with the correct colors

---

### User Story 4 - connectionerror (Priority: P2)

When the connection fails or the network is interrupted, show clear error messages and provide a reconnect option.

**Why this priority**: This is important for user experience, but it can be implemented after the core functionality works.

**Independent Test**: Attempt a connection while the network is disconnected and verify that an error message is shown.

**Acceptance Scenarios**:

1. **Given** the user tries to connect with an invalid host name, **When** a connection timeout occurs, **Then** a timeout error message is shown
2. **Given** an SSH connection is active, **When** the network is disconnected, **Then** a disconnection notice and reconnect button are shown
3. **Given** the authentication details are incorrect, **When** the user attempts to connect, **Then** an authentication error message is shown

---

### User Story 5 - terminalresize (Priority: P3)

The terminal size automatically adjusts in response to device screen size changes and rotation.

**Why this priority**: This is functionally important, but basic operation is still possible at a fixed size.

**Independent Test**: Rotate the device and verify that the terminal size changes accordingly.

**Acceptance Scenarios**:

1. **Given** the terminal screen is visible, **When** the device is rotated between portrait and landscape, **Then** the terminal size updates to match the new screen size

---

### Edge Cases

- Behavior when the app is sent to the background during an SSH connection
- When authentication details (password or SSH key) cannot be retrieved from storage
- When tmux is not installed on the remote server
- When the session is deleted from another client

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: TerminalScreen must accept `connectionId` and establish an SSH connection using the corresponding connection information
- **FR-002**: After the SSH connection is established, it must retrieve the tmux session list and attach to an existing session
- **FR-003**: If no tmux session exists, it must create and attach to a new session
- **FR-004**: It must display data from the SSH shell (`stdout`/`stderr`) in the xterm Widget in real time
- **FR-005**: It must send key input from the special key bar to the remote side over SSH
- **FR-006**: It must send input from the text input dialog to the remote side over SSH
- **FR-007**: It must properly clean up the SSH connection when the terminal screen is closed
- **FR-008**: It must display user-friendly error messages for connection and authentication failures
- **FR-009**: It must synchronize the tmux window size when the screen size changes

### Key Entities

- **Connection**: SSH connection information (host, port, username, authentication method)
- **SshClient**: Manages the SSH connection and handles data send/receive
- **TmuxSession**: tmux session information (name, window list)
- **Terminal**: The xterm Widget backend and ANSI sequence handling

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can see remote output on the terminal screen within 3 seconds of tapping a connection, excluding network latency
- **SC-002**: Input-to-screen latency is kept within 200 ms
- **SC-003**: When a connection error occurs, the user is notified within 5 seconds
- **SC-004**: ANSI 256 colors are rendered correctly
- **SC-005**: SSH connection resources are reliably released when returning from the terminal screen

## Assumptions

- tmux is installed on the remote server; fallback behavior for missing tmux will be addressed later
- Authentication details (password or SSH key) are already stored in `flutter_secure_storage`
- Network connectivity is generally stable; automatic reconnection on unstable networks will be addressed later
- The initial terminal size is 80 columns by 24 rows



