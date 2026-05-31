# Agent Interface Shortcuts

## Summary

Add a saved per-connection setting that selects which agent shortcut interface MuxPod shows in the terminal special keys bar. Existing and new connections default to the current Claude Code shortcut layout. Users can edit a saved connection and switch the interface between Claude Code and Codex.

## Goals

- Preserve current Claude Code shortcut behavior for existing connections.
- Let each connection choose an agent interface independently.
- Add a Codex interface with shortcuts for plan mode, reasoning effort, and transcript mode.
- Keep the setting in the connection edit form, not as a live terminal control.
- Keep shortcut mappings centralized so future agent profiles or Codex shortcut updates are straightforward.

## Non-Goals

- No fully customizable shortcut editor.
- No terminal-screen runtime switcher.
- No mux, PTY, SSH, or backend behavior changes.
- No automatic detection of whether Claude Code or Codex is running inside the remote shell.

## Data Model

Add `agentInterface` to `Connection` with string values:

- `claude`
- `codex`

The field defaults to `claude` in the constructor and in `Connection.fromJson`. This migrates existing saved connections without changing their terminal shortcut behavior.

`Connection.copyWith`, `toJson`, and `fromJson` must include the field. Missing or unknown values should fall back to `claude`.

## Connection Form

`ConnectionFormScreen` gets local state named `_agentInterface`, defaulting to `claude`.

When editing an existing connection, load `_agentInterface` from the connection. When saving, persist it into the `Connection`.

Add an `AGENT INTERFACE` field in the existing Server section near `MUX TYPE` and `TRANSPORT`. The field should offer:

- `Claude Code`
- `Codex`

A dropdown matches the current form patterns and keeps implementation scoped.

## Shortcut Profiles

Introduce a small `AgentInterface` enum plus a profile mapping for `SpecialKeysBar`. `SpecialKeysBar` receives an `agentInterface` parameter that defaults to Claude, preserving existing tests and call sites.

### Claude Code Profile

Claude Code keeps the current layout:

| Slot | Button | Action |
| --- | --- | --- |
| 1 | PgUp | Page up |
| 2 | PgDn | Page down |
| 3 | Transcript | Ctrl+O |
| 4 | Mode | Shift+Tab |
| 5 | Interrupt | Ctrl+C |
| 6 | Quick Actions | Toggle quick actions row |

Quick actions remain:

`1 | 2 | 3 | 4 | Y | N`

### Codex Profile

Codex uses the same six-slot navigation structure:

| Slot | Button | Action |
| --- | --- | --- |
| 1 | PgUp | Page up |
| 2 | PgDn | Page down |
| 3 | Plan | Shift+Tab |
| 4 | Effort | Toggle effort row |
| 5 | Transcript | Ctrl+T |
| 6 | Quick Actions | Toggle quick actions row |

The Codex effort row appears above the navigation row and contains:

| Button | Action |
| --- | --- |
| Lower | Alt+, (`ESC ,`) |
| Raise | Alt+. (`ESC .`) |

The existing quick-actions row still provides:

`1 | 2 | 3 | 4 | Y | N`

## Source Notes

The Codex mappings follow current public Codex CLI behavior:

- OpenAI Codex CLI slash-command docs describe `/plan` and `/model`, including model and reasoning effort selection.
- The Codex TUI has a quick collaboration-mode shortcut through `Shift+Tab` for Plan and Default modes.
- Codex CLI `rust-v0.124.0` release notes added quick reasoning controls: `Alt+,` lowers reasoning and `Alt+.` raises reasoning.
- Public Codex CLI issue context documents `Ctrl+T` as the transcript overlay toggle.

## Terminal Wiring

`TerminalScreen` should resolve the active connection by `widget.connectionId` while building `SpecialKeysBar`, then pass the selected interface:

`connection?.agentInterface ?? AgentInterface.claude`

Using `ref.watch(connectionsProvider)` is acceptable here because it lets an already-open terminal reflect a saved connection edit when the provider updates. The feature still does not expose a terminal-screen switch.

No PTY, mux backend, SSH, or reconnection logic changes are required.

## Error Handling

Missing or malformed `agentInterface` values fall back to Claude Code. The connection form should only allow the two known values, so normal saves cannot create invalid values.

No user-facing error is needed for migration or malformed stored data because preserving current behavior is the safest fallback.

## Testing

Add or update focused tests for:

- `Connection.fromJson` defaults missing `agentInterface` to `claude`.
- `Connection.toJson` persists `agentInterface`.
- `ConnectionFormScreen` shows the Agent Interface field.
- Editing a connection can load and save `codex`.
- `SpecialKeysBar` default/Claude behavior remains unchanged.
- `SpecialKeysBar(agentInterface: codex)` renders Codex controls and sends:
  - Shift+Tab for Plan.
  - Ctrl+T for Transcript.
  - Alt+, for Lower effort.
  - Alt+. for Raise effort.
- `TerminalScreen` passes the current connection interface into `SpecialKeysBar` if the existing harness supports it cleanly; otherwise verify this manually during implementation.

## Implementation Scope

Expected files:

- `lib/providers/connection_provider.dart`
- `lib/screens/connections/connection_form_screen.dart`
- `lib/screens/terminal/terminal_screen.dart`
- `lib/widgets/special_keys_bar.dart`
- Relevant widget/provider tests under `test/`

Run `flutter analyze` and focused Flutter tests after implementation. In this environment, Flutter commands must be run with escalated permissions immediately.
