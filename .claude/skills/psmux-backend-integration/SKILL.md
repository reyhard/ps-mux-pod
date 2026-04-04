---
name: psmux-backend-integration
description: Use when working on psmux support, debugging session detection, or fixing command compatibility issues between tmux and psmux
---

# psmux Backend Integration

## Overview

psmux is "command-compatible" with tmux but has critical differences. This skill documents the known quirks and the patterns used to work around them.

## Known psmux Differences from tmux

| Feature | tmux | psmux |
|---------|------|-------|
| `-F` format flag | Fully supported | Supported for `list-panes -a`, but output may be partial |
| `list-panes -a` | Returns ALL sessions' panes | Returns only current/attached session's panes |
| `list-sessions` default output | `name: N windows (created DATE)` | Same format |
| Shell startup noise | None typically | `Keeping computer awake` prefix in stdout |
| tmux path detection | `/usr/bin/tmux` etc. | Not in PATH as `tmux`; `_detectTmuxPath` returns null |

## Command Resolution

All `TmuxCommands.*` calls go through `_resolveMuxCmd()` in `terminal_screen.dart`:

```dart
String _resolveMuxCmd(String cmd) {
  if (_muxBackendName == 'psmux') {
    return cmd.replaceFirst('tmux ', 'psmux ');
  }
  return cmd;
}
```

This must be applied to EVERY code path that sends tmux commands, including:
- `terminal_screen.dart` — polling, key sending, session management
- `connections_screen.dart` — `_fetchSessions()` session listing

## Fallback Parsing Chain

When formatted output (`|||` delimiters) is unavailable or incomplete:

1. Try `parseFullTree()` (expects `|||`-delimited `list-panes -a` output)
2. If no `|||` found → fallback to `parseSessions()` with default format
3. `parseSessions()` tries custom format first, then `_parseDefaultSessionLine()` regex
4. After session detection, if active session has empty `windows` list → call `_fetchWindowsAndPanesForSession()` individually

### Default Format Parsers

- `_parseDefaultSessionLine()`: `name: N windows (created DATE) (attached)?`
- `parseWindowsDefault()`: `0: bash* (1 panes) [80x24]`
- `parsePanesDefault()`: `0: [80x24] [history ...] %0 (active)`

## Shell Noise Handling

psmux SSH sessions emit `Keeping computer awake` as first line of stdout. The parsers handle this by:
- `parseFullTree`: skips lines with `parts.length < 10`
- `parseSessions`: `parseSessionLine` returns null for non-delimited lines, `_parseDefaultSessionLine` also won't match

## Detection Flow

In `_connectAndSetup()` → `_detectAndSetupMuxBackend()`:

1. If `connection.muxType == 'psmux'` → use PsmuxBackend directly
2. If `connection.muxType == 'tmux'` → use TmuxBackend directly
3. If `'auto'` → `MuxDetector` probes `psmux -V` then `tmux -V`

## Architecture

```
Connection.muxType ('auto'|'tmux'|'psmux')
    ↓
MuxDetector.detect() [if auto]
    ↓
_muxBackendName = 'tmux' | 'psmux'
    ↓
_resolveMuxCmd() applied to all TmuxCommands.*
    ↓
TmuxParser with fallback chain
```

## Files Involved

- `lib/services/mux/mux_detector.dart` — backend auto-detection
- `lib/services/mux/tmux_backend.dart` — MuxBackend impl for tmux
- `lib/services/mux/psmux_backend.dart` — MuxBackend impl for psmux
- `lib/services/mux/ssh_executor.dart` — CommandExecutor over SSH
- `lib/services/tmux/tmux_parser.dart` — parsing with fallback chain
- `lib/screens/terminal/terminal_screen.dart` — wiring, `_resolveMuxCmd`
- `lib/screens/connections/connections_screen.dart` — `_fetchSessions`
- `lib/providers/connection_provider.dart` — `muxType` field on Connection
