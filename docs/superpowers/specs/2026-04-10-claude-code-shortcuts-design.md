# Claude Code Shortcuts in Navigation Row

## Summary

Replace the Home/End/Del/Ins buttons in the special keys bar navigation row with Claude Code shortcut buttons (icons, compact). Add a toggleable quick-actions row for number selection and yes/no responses.

## Motivation

When running Claude Code inside a psmux/tmux session, users need quick tap access to Claude Code's interactive shortcuts (transcript view, mode switching, interrupt, option selection). The current Home/End/Del/Ins buttons are rarely used on mobile and waste valuable space that could serve this workflow.

## Navigation Row Layout

The top row currently has 6 uniform buttons: `PgUp | PgDn | Home | End | Del | Ins`.

New layout — same 6 slots, uniform sizing, no visual grouping or accent colors:

| Slot | Function | Action | Rendering |
|------|----------|--------|-----------|
| 1 | PgUp | Send `\x1b[5~` (page up) | Text: "PgUp" (unchanged) |
| 2 | PgDn | Send `\x1b[6~` (page down) | Text: "PgDn" (unchanged) |
| 3 | Transcript | Send Ctrl+O (`\x0f`) | Icon: `Icons.description_outlined` |
| 4 | Mode toggle | Send Shift+Tab (`\x1b[Z`) | Icon: `Icons.route_outlined` |
| 5 | Interrupt | Send Ctrl+C (`\x03`) | Icon: `Icons.stop_circle_outlined` |
| 6 | Quick Actions | Toggle quick-actions row | Icon: `Icons.keyboard_command_key` |

- Slots 3-5 send keystrokes via `onSpecialKeyPressed` (escape sequences / control characters).
- Slot 6 is a local toggle — it does not send a keystroke; it controls visibility of the quick-actions row.

## Quick Actions Row

When the Quick Actions toggle (slot 6) is active, a row slides in **above** the navigation row. Contains 6 uniform buttons:

| Slot | Label | Action |
|------|-------|--------|
| 1 | `1` | Send literal "1" |
| 2 | `2` | Send literal "2" |
| 3 | `3` | Send literal "3" |
| 4 | `4` | Send literal "4" |
| 5 | `Y` | Send literal "y" |
| 6 | `N` | Send literal "n" |

Behavior:
- Row stays visible until the toggle button is tapped again.
- Toggle button gets an active-state visual (same pattern as the RAW button when enabled).
- Buttons send keystrokes via `onKeyPressed` (literal characters, not escape sequences).
- Row uses the same styling and background as the navigation row.

## Implementation Scope

All changes in a single file: `lib/widgets/special_keys_bar.dart`.

### What changes

- **`_buildNavigationKeysRow()`** — replace slots 3-6 (Home/End/Del/Ins) with 3 icon buttons + 1 toggle button.
- **New state variable** — `bool _quickActionsOpen = false` (same pattern as `_rawInputEnabled`).
- **New `_buildQuickActionsRow()`** — renders the `1|2|3|4|Y|N` row. Conditionally shown in the `Column` children list above `_buildNavigationKeysRow()`.
- **New `_buildIconKeyButton()`** — helper that renders a Material Icon instead of text. Reuses the same sizing and styling as `_buildSpecialKeyButton`.
- **New `_buildQuickActionsToggle()`** — same pattern as `_buildRawInputButton()`. Toggles `_quickActionsOpen` state.

### What doesn't change

- Modifier row (ESC, TAB, CTRL, ALT, SHIFT, RET, S-RET, /, -).
- Arrow keys row.
- DirectInput / RAW input behavior.
- No new files needed.
- No changes to `terminal_screen.dart`.
