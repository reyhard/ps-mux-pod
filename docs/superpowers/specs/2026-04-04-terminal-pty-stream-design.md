# Terminal PTY Stream & xterm.dart Rewrite

**Date:** 2026-04-04
**Status:** Approved

## Problem

MuxPod's terminal has high latency (2000ms+) compared to apps like Termius because it polls `tmux capture-pane` at 200-2000ms intervals, parses ANSI output, and renders with a custom `AnsiTextView`. Text is not properly adjusted for screen size. The battery optimization prompt fires on every SSH connection with no way to suppress it.

## Solution

Replace the polling-based terminal with a direct PTY stream via `tmux attach`, replace the custom renderer with xterm.dart, and add a battery optimization setting.

## Architecture

### Two SSH Channels

1. **PTY Channel** (real-time) — Runs `tmux attach-session -t <session>`. Raw PTY output streams directly into xterm.dart's `Terminal` model. User keystrokes flow back through this channel. Zero polling, real-time bidirectional.

2. **Side Channel** (low-frequency) — Existing persistent shell. Handles:
 - Session/window/pane tree refresh (`list-panes -a`) — every ~10s or on-demand
 - Pane switching (`select-pane -t %X`, `select-window -t ...`)
 - Session switching (`switch-client -t <session>`)
 - Keep-alive pings

### Data Flow

```
[PTY stream] ──→ Terminal.write(data) ──→ TerminalView (renders)
[User input] ──→ Terminal.onOutput ──→ PTY channel.write(data)
[Session drawer tap] ──→ Side channel: exec("tmux select-pane -t %X")
[Tree refresh timer] ──→ Side channel: exec("tmux list-panes -a -F ...")
[Screen resize] ──→ Terminal.onResize ──→ session.resizeTerminal(cols, rows)
```

## Terminal Renderer: xterm.dart

**Package:** `xterm` from pub.dev (new dependency).

**Core components:**
- `Terminal` — The model. Holds screen buffer, scrollback, cursor state. `terminal.write(bytes)` processes incoming PTY data.
- `TerminalView` — The widget. Renders the terminal via `CustomPainter`, handles text selection, reports size in columns/rows.
- `terminal.onOutput` — Stream of bytes from user input. Piped to PTY channel.
- `terminal.onResize` — Fires on layout change. Forwarded to `session.resizeTerminal(cols, rows)`.

**What xterm.dart replaces:**
- `AnsiParser` — full VT100/xterm escape sequence handling
- `AnsiTextView` — proper terminal rendering with `CustomPainter`
- `ScrollbackBuffer` — built-in scrollback
- `FontCalculator` — automatic column/row calculation from widget size
- `TerminalDisplayProvider` — terminal state lives in `Terminal` object
- Screen fitting — `TerminalView` natively adjusts content to available screen size

**Font configuration:** `TerminalStyle` with existing HackGenConsole/UDEVGothicNF fonts and user's `fontSize` setting.

**Pinch zoom:** Adjusts `TerminalStyle.fontSize` dynamically, same as current behavior.

## Input Handling

All user input now goes through the PTY channel directly instead of `tmux send-keys`:

### Enter Command Dialog
- UI stays exactly as-is (modal with text field, Execute button)
- On Execute: writes text bytes + `\n` to PTY channel (instead of `tmux send-keys -l`)

### Live Mode (Direct Input)
- Characters go directly to the PTY stream in real-time
- IME handling stays the same (Flutter-level concern)
- Significantly faster than per-keystroke `tmux send-keys`

### Special Keys Bar
- Same UI and layout
- Key mappings change from tmux names to VT100 escape sequences:
 - PgUp: `\x1b[5~`
 - PgDn: `\x1b[6~`
 - Ctrl+C: `\x03`
 - Arrow Up: `\x1b[A`
 - etc.
- Modifier toggles (Ctrl/Alt/Shift sticky) stay the same

### Hardware Keyboard
- xterm.dart's `TerminalView` captures hardware keyboard input natively
- Emits bytes via `terminal.onOutput`
- Piped to PTY channel

### Input Queue
- Stays for buffering during disconnect
- Buffers raw bytes instead of tmux commands
- Flushes to PTY channel on reconnect

## Session Navigation

### Session Drawer
- UI stays as-is — tree view of sessions/windows/panes
- Pane switch: `tmux select-pane -t %X` via side channel
- Window switch: `tmux select-window -t session:N` via side channel
- Swipe navigation: same gesture, `select-pane` via side channel

### Session Switching
- `tmux switch-client -t <new_session>` sent through the PTY channel
- No channel teardown needed — tmux handles it natively, PTY stream continues

### Tree Refresh
- Same `list-panes -a` polling on the side channel (~10s interval)
- No change from current behavior

## SSH Client Changes

### New Channel Structure
1. **PTY Shell** — `client.shell(pty: SSHPtyConfig(width, height, type: 'xterm-256color'))`. Runs `tmux attach-session -t <session>`. Stdout pipes to `terminal.write()`.
2. **Side Channel** — Existing persistent shell with marker-based execution.

### New Methods
- `attachSession(sessionName)` — opens PTY shell, runs `tmux attach`, returns stdout stream
- `switchSession(sessionName)` — sends `switch-client -t` through PTY
- `resizeTerminal(cols, rows)` — already exists, targets PTY shell

### Reconnection
- On SSH disconnect: PTY channel is lost
- On reconnect: open new PTY shell → `tmux attach` (tmux session survives on server)
- xterm.dart screen state is stale but tmux redraws on attach, so terminal self-corrects

## Battery Optimization Setting

**New setting:** `askBatteryOptimization` (bool, default: `true`)

- **Settings screen:** New toggle under Connection section — "Ask to disable battery optimization"
- **Logic in `ForegroundTaskService`:** Check the setting before calling `requestIgnoreBatteryOptimization()`. If `false`, skip silently.
- User can re-enable the prompt any time via settings

## Code to Remove

### Remove entirely:
- `lib/screens/terminal/widgets/ansi_text_view.dart` (~1000 lines) — replaced by `TerminalView`
- `lib/services/terminal/ansi_parser.dart` — xterm.dart handles escape sequences
- `lib/services/terminal/terminal_diff.dart` — no more polling/diffing
- `lib/services/terminal/scrollback_buffer.dart` — xterm.dart built-in scrollback
- `lib/services/terminal/font_calculator.dart` — xterm.dart calculates cols/rows
- `lib/providers/terminal_display_provider.dart` — state lives in `Terminal` object

### Heavily simplify:
- `lib/screens/terminal/terminal_screen.dart` — rewrite around `TerminalView` + PTY stream. Remove polling loop, capture-pane logic, diff handling, scroll-mode buffering (~400 lines removed).
- `lib/services/ssh/ssh_client.dart` — remove polling shell, `execInput()`, `getPaneInfo()`, `_pollPaneContent()`. Add `attachSession()`.
- `lib/widgets/special_keys_bar.dart` — replace tmux key name mappings with VT100 escape sequences.

### Keep as-is:
- Session drawer, pane navigator, tmux parser
- Settings provider (plus new battery setting)
- Network monitor, reconnection logic
- SSH auth, key management
- All screens except terminal

**Net result:** ~2000 lines removed, cleaner architecture, real-time terminal performance.

## MuxBackend Abstraction Compatibility

This design targets the **tmux backend** specifically (`tmux attach-session`). The ongoing MuxBackend abstraction should expose a generic `attachSession()` / PTY stream interface that each backend implements:

- **TmuxBackend**: `tmux attach-session -t <session>` on a PTY shell
- **PsmuxBackend**: Equivalent attach mechanism (implementation deferred to psmux work)

The `terminal_screen.dart` rewrite should consume the PTY stream through the `MuxBackend` interface, not directly through tmux commands, so that psmux can plug in later without terminal screen changes.
