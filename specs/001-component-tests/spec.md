# Feature Specification: Component Tests

**Feature Branch**: `001-component-tests`
**Created**: 2026-01-10
**Status**: Draft
**Input**: User description: "Add component tests. Using React Native Testing Library. Tests for ConnectionCard, TerminalView, SpecialKeys, and SessionTabs."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ConnectionCard Test Coverage (Priority: P1)

As a developer, tests are needed to verify the behavior of the ConnectionCard component. The connection card is a primary navigation element, and we want to ensure that connection status display, session expansion, and user interactions function correctly.

**Why this priority**: ConnectionCard is the core UI of the app and the first element users interact with. Highest priority to prevent regressions.

**Independent Test**: Can run only the ConnectionCard tests to verify that card display, tap, expansion, and session selection work correctly.

**Acceptance Scenarios**:

1. **Given** connection info is provided, **When** the card is rendered, **Then** connection name, host, and username are displayed
2. **Given** connection status is "connected", **When** the card is displayed, **Then** a green status dot indicating connected is shown
3. **Given** a session list exists, **When** the card is tapped, **Then** the session list is expanded and displayed
4. **Given** the session list is expanded, **When** a session is tapped, **Then** the onSelectSession callback is called
5. **Given** a connection in error state, **When** the card is displayed, **Then** an error message is shown

---

### User Story 2 - SpecialKeys Test Coverage (Priority: P1)

As a developer, tests are needed to verify the behavior of the SpecialKeys component. Special key input is essential for terminal operations, and we want to ensure that ESC, TAB, CTRL, ALT, and other key transmissions function correctly.

**Why this priority**: Essential functionality for terminal operations; key input malfunctions are critical.

**Independent Test**: Can run only the SpecialKeys tests to verify that tapping each key button correctly triggers the callback.

**Acceptance Scenarios**:

1. **Given** the component is rendered, **When** the ESC button is tapped, **Then** onSendSpecialKey is called with "Escape"
2. **Given** the component is rendered, **When** the TAB button is tapped, **Then** onSendSpecialKey is called with "Tab"
3. **Given** CTRL mode is off, **When** the CTRL button is tapped, **Then** CTRL mode turns on and the button shows active state
4. **Given** CTRL mode is on, **When** a literal key (e.g., /) is tapped, **Then** onSendCtrl is called and CTRL mode turns off
5. **Given** disabled=true, **When** any button is tapped, **Then** callbacks are not triggered

---

### User Story 3 - SessionTabs Test Coverage (Priority: P2)

As a developer, tests are needed to verify the behavior of the SessionTabs component. Session tabs are an important navigation element, and we want to ensure that tab display, selection state, and attach state function correctly.

**Why this priority**: Important as a navigation feature, but simpler structure than ConnectionCard.

**Independent Test**: Can run only the SessionTabs tests to verify tab display, selection, and empty state handling.

**Acceptance Scenarios**:

1. **Given** multiple sessions exist, **When** the component is rendered, **Then** all session names are displayed as tabs
2. **Given** session tabs are displayed, **When** a tab is tapped, **Then** the onSelect callback is called with the session name
3. **Given** a session is selected, **When** the component is displayed, **Then** the selected tab is shown with active style
4. **Given** an attached session exists, **When** the component is displayed, **Then** an attached badge is shown
5. **Given** there are 0 sessions, **When** the component is rendered, **Then** a "No sessions" message is displayed

---

### User Story 4 - TerminalView Test Coverage (Priority: P2)

As a developer, tests are needed to verify the behavior of the TerminalView component. Terminal display requires ANSI color support, and we want to ensure that line/span display and style application function correctly.

**Why this priority**: Core UI feature, but display-only with no complex interactions.

**Independent Test**: Can run only the TerminalView tests to verify text display, ANSI style application, and empty line handling.

**Acceptance Scenarios**:

1. **Given** line data containing text spans exists, **When** the component is rendered, **Then** the text content is displayed
2. **Given** a span with a specified foreground color exists, **When** the component is rendered, **Then** text is displayed in the specified color
3. **Given** a span with bold attribute exists, **When** the component is rendered, **Then** text is displayed in bold
4. **Given** a line with an empty span array exists, **When** the component is rendered, **Then** it is displayed as an empty line with appropriate height
5. **Given** a custom theme is specified, **When** the component is rendered, **Then** the theme's background color is applied

---

### Edge Cases

- When long connection names/hostnames are passed to ConnectionCard, are they properly truncated?
- Does the mutual exclusion between CTRL mode and ALT mode in SpecialKeys work correctly?
- When there are many sessions (10+) in SessionTabs, is it scrollable?
- When extremely long lines (1000+ characters) exist in TerminalView, are they properly wrapped?
- When undefined/null props are passed to each component, does it avoid crashing?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Tests must be implemented using React Native Testing Library
- **FR-002**: Each component test must be independently executable
- **FR-003**: Tests must use the project's existing jest.config.js and jest.setup.js
- **FR-004**: Test files must be placed in the __tests__/components/ directory
- **FR-005**: Each test must cover the component's primary features (rendering, event handling, state changes)
- **FR-006**: External dependencies requiring mocks (icons, etc.) must be properly mocked

### Key Entities

- **ConnectionCard**: A card that displays connection information. Includes connection status, session list, and error display
- **TerminalView**: ANSI color-compatible terminal display. Composed of lines and spans
- **SpecialKeys**: Special key input bar. Includes ESC, TAB, CTRL, ALT, and literal keys
- **SessionTabs**: Tab display for tmux session list. Shows selection state and attach state

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Test files must exist for all 4 components
- **SC-002**: At least 5 test cases must pass for each component
- **SC-003**: All tests must execute and complete successfully with `pnpm test`
- **SC-004**: Test coverage must cover the primary paths of rendering, events, and state changes

## Assumptions

- Existing jest.config.js and jest.setup.js are correctly configured
- React Native Testing Library is already installed in the project
- Additional mock configuration will be added if @expo/vector-icons mocking is needed
- Test execution environment uses the jest-expo preset
