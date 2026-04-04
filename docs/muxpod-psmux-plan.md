# MuxPod → psmux + WSL Hybrid Conversion Plan

## Current Architecture (mux-pod)

MuxPod is a Flutter/Dart mobile app that:
- **Connects** to remote servers over SSH (via `dartssh2`)
- **Parses** tmux state by running tmux commands over the SSH channel (`tmux list-sessions`, `tmux list-windows`, `tmux list-panes`, etc.)
- **Renders** terminal output in an embedded xterm widget
- **Manages** sessions/windows/panes through a touch-optimized UI with 5-tab navigation (Dashboard, Servers, Alerts, Keys, Settings)

Key layers:
1. **Transport** — SSH connection management (dartssh2)
2. **Mux Protocol** — tmux command parsing (list-sessions, capture-pane, send-keys, etc.)
3. **Terminal Emulation** — xterm.dart rendering
4. **UI** — Riverpod state, Flutter widgets

---

## Target Architecture: psmux with nested WSL/tmux

```
┌─────────────────────────────────────────────────┐
│ MuxPod (Flutter) │
│ │
│ ┌──────────────────────────────────────────┐ │
│ │ Multiplexer Abstraction Layer │ │
│ │ ┌──────────┐ ┌───────────────┐ │ │
│ │ │ tmux │ │ psmux │ │ │
│ │ │ backend │ │ backend │ │ │
│ │ └──────────┘ └───────────────┘ │ │
│ └──────────────────────────────────────────┘ │
│ │
│ ┌──────────────┐ ┌───────────────────────┐ │
│ │ SSH tunnel │ │ Local/Named Pipe │ │
│ │ (dartssh2) │ │ transport (psmux) │ │
│ └──────────────┘ └───────────────────────┘ │
└─────────────────────────────────────────────────┘
```

For a psmux session hosting WSL with tmux inside, the nesting looks like:

```
psmux session (Windows)
 └─ psmux pane running: wsl -d Ubuntu
 └─ tmux (Linux) inside WSL
 ├─ tmux window 0: editor
 ├─ tmux window 1: build
 └─ tmux window 2: logs
```

---

## Phase 1: Abstract the Multiplexer Protocol

### 1.1 Define a `MuxBackend` interface

```dart
abstract class MuxBackend {
 String get name; // "tmux" or "psmux"
 
 Future<List<MuxSession>> listSessions();
 Future<MuxSession> newSession({String? name});
 Future<void> killSession(String sessionId);
 Future<void> attachSession(String sessionId);
 
 Future<List<MuxWindow>> listWindows(String sessionId);
 Future<MuxWindow> newWindow(String sessionId, {String? name});
 Future<void> selectWindow(String sessionId, int index);
 
 Future<List<MuxPane>> listPanes(String windowTarget);
 Future<void> splitPane(String target, {bool horizontal = true});
 Future<void> selectPane(String target, int index);
 
 Future<String> capturePane(String target);
 Future<void> sendKeys(String target, String keys);
 
 // For nested scenarios
 Future<MuxBackend?> getNestedBackend(String paneTarget);
}
```

### 1.2 Implement `TmuxBackend` (extract from current code)

Move all existing tmux command parsing into a class implementing `MuxBackend`. This is mostly a refactor — the commands stay the same:
- `tmux list-sessions -F "#{session_id}:#{session_name}:..."` 
- `tmux list-windows -t $session -F "..."`
- etc.

### 1.3 Implement `PsmuxBackend`

psmux is tmux-compatible (76 commands, same syntax), so:
- Start by **inheriting or delegating** to `TmuxBackend`
- Override where psmux diverges (config paths, WSL-specific behavior)
- Key difference: transport is **not SSH** — psmux runs locally on Windows

---

## Phase 2: Add a Local Transport Layer

### 2.1 Current: SSH-only transport

All commands currently go through: `sshClient.execute("tmux ...")`.

### 2.2 New: Pluggable command executor

```dart
abstract class CommandExecutor {
 Future<String> execute(String command);
 Future<ProcessShell> shell(); // for interactive terminal
}

class SshExecutor implements CommandExecutor {
 // Existing dartssh2 logic
}

class LocalExecutor implements CommandExecutor {
 // Runs commands via Process.run on the local machine
 // Used when MuxPod runs on Windows desktop targeting local psmux
}

class WslBridgeExecutor implements CommandExecutor {
 // Wraps commands: wsl -d <distro> -- <command>
 // Used to reach tmux inside WSL from a psmux pane
}
```

### 2.3 Named pipe / local socket option

For Windows desktop builds, psmux could potentially be controlled via:
- Direct CLI invocation (`Process.run("psmux", ["ls"])`)
- Or a future psmux socket/API if one is added

---

## Phase 3: Nested Multiplexer Support

This is the core of your use case: **psmux → WSL → tmux**.

### 3.1 Multiplexer tree model

```dart
class MuxNode {
 final MuxBackend backend;
 final CommandExecutor executor;
 final MuxNode? parent;
 final List<MuxNode> children; // nested muxers
 final String? paneTarget; // which parent pane hosts this
 
 // e.g. root = PsmuxBackend(LocalExecutor)
 // child = TmuxBackend(WslBridgeExecutor) hosted in psmux pane 0
}
```

### 3.2 Detection logic

When the user drills into a psmux pane, MuxPod should detect if it contains a nested tmux:
1. `psmux capture-pane -t <target>` — check for tmux status bar
2. Or probe: `wsl -d Ubuntu -- tmux ls` — if it returns sessions, offer nested view
3. Let the user manually flag a pane as "WSL + tmux"

### 3.3 UI: Breadcrumb navigation

```
[psmux:work] → [wsl:Ubuntu] → [tmux:dev] → window:editor → pane:0
```

The header bar becomes a breadcrumb showing the full nesting path. Tapping any segment navigates to that level.

---

## Phase 4: Platform / Transport Matrix

| MuxPod runs on | Target | Transport | Mux backend |
|---------------------|---------------------|------------------|-------------|
| Android (current) | Remote Linux server | SSH | tmux |
| Android | Windows PC (psmux) | SSH → psmux CLI | psmux |
| Android | Windows → WSL | SSH → wsl → tmux | tmux (nested)|
| Windows desktop | Local psmux | Local process | psmux |
| Windows desktop | Local WSL tmux | wsl -- tmux | tmux |
| Windows desktop | Remote Linux | SSH | tmux |

### Server config changes

Add to the server model:
```dart
enum MuxType { tmux, psmux, auto }
enum TransportType { ssh, local }

class ServerConfig {
 // ... existing fields ...
 MuxType muxType; // default: auto (detect)
 TransportType transport; // default: ssh
 String? wslDistro; // if connecting to WSL inside psmux
 bool nestedTmux; // expect tmux inside WSL pane
}
```

---

## Phase 5: Implementation Order

### Sprint 1 — Refactor (no new features)
- [ ] Extract current tmux logic into `TmuxBackend` + `MuxBackend` interface
- [ ] Extract SSH execution into `SshExecutor` + `CommandExecutor` interface
- [ ] All existing tests still pass, zero behavior change

### Sprint 2 — psmux backend
- [ ] Implement `PsmuxBackend` (mostly delegates to `TmuxBackend` since syntax is compatible)
- [ ] Add `MuxType` detection: run `psmux -V` vs `tmux -V` on connect
- [ ] Server config UI: allow choosing tmux / psmux / auto

### Sprint 3 — Local transport (Windows desktop)
- [ ] Add Windows desktop build target (Flutter already has a `windows/` dir)
- [ ] Implement `LocalExecutor` for controlling local psmux
- [ ] "Local server" card in Servers tab — no SSH needed

### Sprint 4 — WSL bridge + nesting
- [ ] Implement `WslBridgeExecutor` wrapping commands with `wsl -d <distro> --`
- [ ] `MuxNode` tree for nested multiplexer navigation
- [ ] Breadcrumb header UI
- [ ] Detection: auto-discover tmux inside WSL panes

### Sprint 5 — Polish
- [ ] Unified session tree view showing psmux → WSL → tmux hierarchy
- [ ] Quick-connect: "WSL tmux" as a first-class connection type
- [ ] Handle edge cases: psmux session dies, WSL not running, tmux not installed in WSL

---

## Key Risks & Mitigations

**Risk: psmux command output differs from tmux**
psmux claims 76 commands and tmux-compatible format strings — but edge cases will exist. Mitigation: build a compatibility test suite that runs the same parsing against both.

**Risk: WSL bridge latency** 
Each command goes through `wsl -- tmux ...` which spawns a process. Mitigation: batch commands where possible, consider keeping a persistent `wsl` shell open.

**Risk: Flutter Windows desktop maturity** 
Flutter desktop on Windows is stable but less battle-tested for terminal use. Mitigation: the xterm.dart widget already supports desktop; focus testing here.

**Risk: psmux is young software** 
It's a relatively new Rust project. API surface may shift. Mitigation: keep the `PsmuxBackend` thin, delegate to `TmuxBackend` for shared logic, pin to a known psmux version.
