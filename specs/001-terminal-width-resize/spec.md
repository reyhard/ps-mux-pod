# Feature Specification: Terminal Width Auto-Resize

**Feature Branch**: `001-terminal-width-resize`
**Created**: 2026-01-11
**Status**: Draft
**Input**: User description: "Terminal width auto-resize feature: when a pane is selected, automatically adjust the terminal display width to match tmux `pane_width`. Allow configuring a minimum font size in settings. Enable horizontal scrolling if the size would go below the minimum. Support pinch zoom in and out."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auto-fit Terminal to Pane Width (Priority: P1)

When the user selects a tmux pane, the terminal display automatically fits the pane width in characters. This lets the user view the terminal with the same layout as on the desktop.

**Why this priority**: This is the core of the feature. Without matching the tmux pane width, lines wrap and the display diverges from the desktop layout. This provides the most important user experience.

**Independent Test**: Select a pane and verify that the terminal display fits the pane width exactly, for example 80, 120, or 200 characters.

**Acceptance Scenarios**:

1. **Given** SSH is connected and a tmux session is open, **When** a pane that is 80 characters wide is selected, **Then** the terminal display fits 80 characters and all text stays within the screen
2. **Given** SSH is connected and a tmux session is open, **When** a pane that is 200 characters wide is selected, **Then** the font size shrinks so the 200-character width fits within the screen
3. **Given** a pane is displayed, **When** the pane is switched to another window, **Then** the display is recalculated for the new pane width

---

### User Story 2 - Minimum Font Size Setting (Priority: P2)

The user can specify the minimum font size in the settings screen. This sets the limit for automatic resizing while preserving readability.

**Why this priority**: Automatic resizing can produce unreadably small fonts. Letting the user set an acceptable minimum is important for both accessibility and UX.

**Independent Test**: Change the minimum font size in the settings screen and verify that the value affects automatic terminal resizing.

**Acceptance Scenarios**:

1. **Given** the settings screen is open, **When** the minimum font size is set to 8 px, **Then** the setting is saved and 8 px is retained on the next launch
2. **Given** the minimum font size is set to 10 px, **When** the pane width is very large, **Then** the font size does not shrink below 10 px

---

### User Story 3 - Horizontal Scroll for Wide Panes (Priority: P2)

If the entire pane still cannot fit within the screen width at the minimum font size, horizontal scrolling becomes available.

**Why this priority**: Because of the minimum font-size limit, extremely wide panes may not fit on screen. Horizontal scrolling ensures all content remains accessible in those cases.

**Independent Test**: Select a very wide pane, for example 300 characters, and verify that the full content can be reviewed through horizontal scrolling.

**Acceptance Scenarios**:

1. **Given** the minimum font size is 10 px and a 300-character-wide pane is displayed, **When** the content still exceeds the screen width at the minimum font size, **Then** horizontal scrolling is enabled and the user can scroll left and right
2. **Given** horizontal scrolling is enabled, **When** the user scrolls to the far right, **Then** the rightmost pane text is shown

---

### User Story 4 - Pinch to Zoom (Priority: P3)

The user can temporarily increase or decrease the font size with pinch gestures.

**Why this priority**: This is a standard mobile gesture and is useful when the user wants to inspect small text or zoom out for an overview. The core use cases are already covered by the P1/P2 features.

**Independent Test**: Pinch in and pinch out while the terminal is displayed and verify that the font size changes dynamically.

**Acceptance Scenarios**:

1. **Given** the terminal is displayed, **When** the user pinches out, **Then** the font size increases
2. **Given** the terminal is displayed, **When** the user pinches in, **Then** the font size decreases, down to the minimum font size
3. **Given** the font size was changed by pinch, **When** the user switches to another pane, **Then** automatic resizing is applied based on the new pane width

---

### Edge Cases

- For extremely narrow panes, for example 10 characters wide, the font size expands to fill the available screen width
- If the pane width is 0 or cannot be retrieved, use the default value of 80 characters
- Recalculate when screen width changes dynamically on foldable devices
- If pane content updates during a pinch gesture, update the content while preserving the display
- Recalculate on portrait/landscape rotation
- Reset the scroll position when switching panes while horizontal scrolling is active

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system must retrieve tmux `pane_width` in characters when a pane is selected
- **FR-002**: The system must automatically calculate a font size that fits within the screen width based on the pane width
- **FR-003**: The user must be able to set the minimum font size in points from the settings screen
- **FR-004**: The system must apply the minimum value when the calculated font size falls below it
- **FR-005**: The system must enable horizontal scrolling when the content still exceeds the screen width at the minimum font size
- **FR-006**: The user must be able to increase or decrease the font size with pinch gestures
- **FR-007**: The system must still enforce the minimum font-size limit during pinch gestures
- **FR-008**: The system must readjust the display when switching panes to match the new pane width
- **FR-009**: The system must recalculate based on width changes when the screen rotates
- **FR-010**: The system must persist the minimum font-size setting

### Key Entities

- **TerminalDisplayState**: Entity that manages terminal display state, including the current font size, pane width in characters, scroll offset, and zoom scale
- **TerminalDisplaySettings**: Entity that manages user settings, stores the minimum font size, and persists it

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Display adjustment completes within 500 ms after pane selection
- **SC-002**: For panes 80 to 200 characters wide, all text is shown without line wrapping when it fits without horizontal scrolling
- **SC-003**: Font-size changes from pinch gestures are displayed smoothly
- **SC-004**: The minimum font-size setting is applied correctly in 100% of cases
- **SC-005**: All pane content remains accessible during horizontal scrolling

## Assumptions

- The default minimum font size is 8 px, which matches common mobile readability guidance
- After a pinch gesture, switching panes returns to auto-fit mode, resetting the user's temporary zoom
- The fallback width when pane width cannot be retrieved is 80 characters, which is the standard terminal width
- This assumes a monospaced font, so the width per character is constant



