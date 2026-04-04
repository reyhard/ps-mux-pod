# MuxBackend Abstraction & psmux Support — Design Spec

## Goal

Refactor MuxPod to support multiple terminal multiplexer backends (tmux, psmux) and transport layers (SSH, local, WSL bridge) through a clean abstraction, enabling nested multiplexer scenarios like `psmux → WSL → tmux`.

## Scope

From the original 5-sprint plan, this spec covers:
- **Sprint 1:** Extract `MuxBackend` + `CommandExecutor` interfaces, implement `TmuxBackend` + `SshExecutor`
- **Sprint 2:** `PsmuxBackend` + auto-detection
- **Sprint 4:** `WslBridgeExecutor` + `MuxNode` nesting + breadcrumb UI

**Excluded:** Sprint 3 (Windows desktop build / `LocalExecutor`) and Sprint 5 (polish) — deferred to future work.

**End goal:** A working APK that can be installed on an Android device.

---

## Prerequisites — Environment Setup

Must be installed **before** any development or build work begins.

### Required

| Tool | Version | Purpose | Install |
|------|---------|---------|---------|
| **Flutter SDK** | 3.24+ | Framework, `flutter build apk` | https://docs.flutter.dev/get-started/install/windows/mobile |
| **Android SDK** (via Android Studio or cmdline-tools) | API 34+ | Android build toolchain | Bundled with Android Studio, or standalone cmdline-tools |
| **Android Studio** | Latest | SDK manager, emulator, Gradle build | https://developer.android.com/studio |

### Already Installed

| Tool | Version | Status |
|------|---------|--------|
| Git | 2.53.0 | OK |
| JDK | Temurin 17.0.2 | OK (Flutter requires JDK 17) |
| Node.js | Latest | OK (not needed for Flutter, but available) |

### Installation Steps

1. **Install Android Studio** → https://developer.android.com/studio
 - During setup, ensure "Android SDK", "Android SDK Command-line Tools", and "Android SDK Build-Tools" are checked
 - After install, open SDK Manager → install **Android API 34** (or latest)
 - Accept all SDK licenses: `flutter doctor --android-licenses`

2. **Install Flutter SDK** → https://docs.flutter.dev/get-started/install/windows/mobile
 - Extract to `C:\src\flutter` (or preferred location)
 - Add `C:\src\flutter\bin` to system PATH
 - Verify: `flutter --version` should show 3.24+

3. **Verify environment:**
 ```bash
 flutter doctor
 ```
 All checks should pass (Flutter, Android toolchain, Android Studio). Chrome/VS Code/connected device checks are optional.

4. **Fetch project dependencies:**
 ```bash
 cd O:\Projects\ps-mux-pod
 flutter pub get
 ```

5. **Test build:**
 ```bash
 flutter build apk --debug
 ```
 This should produce `build/app/outputs/flutter-apk/app-debug.apk`.

### Optional (for on-device testing)

- **USB debugging** enabled on Android phone (Settings → Developer options → USB debugging)
- **ADB** (bundled with Android SDK) — verify with `adb devices` when phone is connected
- Or use Android Studio's emulator for testing without a physical device

---

## Execution Strategy: Max Blast with Subagents

### Overview

3 phases, 7 agent invocations total: 1 seed + 5 parallel + 1 integration.

```
Phase 0: SEED (Sonnet, main branch)
 │ Create interface-only files in lib/services/mux/
 │ Commit to main
 │
Phase 1: BLAST (5 agents in parallel worktrees)
 │
 │ ┌─ Agent 1 (Sonnet) ─── TmuxBackend + tests
 │ ├─ Agent 2 (Haiku) ─── SshExecutor + tests
 │ ├─ Agent 3 (Sonnet) ─── PsmuxBackend + detector + tests
 │ ├─ Agent 4 (Sonnet) ─── WslBridgeExecutor + MuxNode + tests
 │ └─ Agent 5 (Opus) ─── UI: models, providers, screens
 │
Phase 2: INTEGRATION (Opus, main branch)
 │ 5-way merge, conflict resolution
 │ flutter analyze + flutter test
 │ Wire end-to-end flow
```

### Checkpoint Rules

- Phase 1 does NOT start until seed commit is on main
- All 5 agents must complete before integration starts
- Integration agent reports merge conflicts + resolution decisions for user review
- If `flutter analyze` or `flutter test` fails post-integration, the integration agent fixes it (no re-dispatch)

---

## Phase 0: Seed Commit — Interface Contracts

### Files Created

```
lib/services/mux/
├── mux_backend.dart # Abstract MuxBackend interface
├── mux_models.dart # MuxSession, MuxWindow, MuxPane
├── command_executor.dart # Abstract CommandExecutor interface
└── mux_types.dart # MuxType, TransportType enums
```

### `MuxBackend` Interface

```dart
abstract class MuxBackend {
 String get name; // "tmux" or "psmux"

 // Sessions
 Future<List<MuxSession>> listSessions();
 Future<MuxSession> newSession({String? name});
 Future<void> killSession(String sessionId);
 Future<void> attachSession(String sessionId);

 // Windows
 Future<List<MuxWindow>> listWindows(String sessionId);
 Future<MuxWindow> newWindow(String sessionId, {String? name});
 Future<void> selectWindow(String sessionId, int index);

 // Panes
 Future<List<MuxPane>> listPanes(String windowTarget);
 Future<void> splitPane(String target, {bool horizontal = true});
 Future<void> selectPane(String target, int index);

 // I/O
 Future<String> capturePane(String target);
 Future<void> sendKeys(String target, String keys);

 // Nesting
 Future<MuxBackend?> getNestedBackend(String paneTarget);
}
```

### `CommandExecutor` Interface

```dart
abstract class CommandExecutor {
 Future<String> execute(String command);
 Future<Stream<List<int>>> shell(); // interactive terminal byte stream (matches dartssh2 SSHSession API)
 Future<void> dispose();
}
```

> **Note:** `shell()` returns a byte stream for interactive terminal I/O. The concrete `SshExecutor` wraps `SSHSession` from dartssh2; `WslBridgeExecutor` wraps a `Process` stdin/stdout. The stream type keeps the interface transport-agnostic.

### Shared Models (`mux_models.dart`)

```dart
class MuxSession {
 final String id;
 final String name;
 final DateTime? created;
 final bool attached;
 final int windowCount;
 final List<MuxWindow> windows;
}

class MuxWindow {
 final int index;
 final String id;
 final String name;
 final bool active;
 final int paneCount;
 final List<MuxPane> panes;
}

class MuxPane {
 final int index;
 final String id;
 final bool active;
 final String? currentCommand;
 final int width;
 final int height;
}
```

### Enums (`mux_types.dart`)

```dart
enum MuxType { tmux, psmux, auto }
enum TransportType { ssh, local, wslBridge }
```

### Model: Sonnet
### Estimated effort: ~10 minutes

---

## Phase 1: Parallel Agent Assignments

### Agent 1 — TmuxBackend Implementation

**Model:** Sonnet

**Owns:**
- `lib/services/mux/tmux_backend.dart`
- `test/services/mux/tmux_backend_test.dart`

**Work:**
- Implement `MuxBackend` by wrapping existing `TmuxCommands` + `TmuxParser`
- Constructor takes a `CommandExecutor` (dependency injection)
- Maps `TmuxSession` → `MuxSession`, `TmuxWindow` → `MuxWindow`, `TmuxPane` → `MuxPane`
- `getNestedBackend()` returns `null` (tmux doesn't nest in this architecture)
- Does NOT modify existing `TmuxCommands`/`TmuxParser` — wraps them

**Tests:** Mock `CommandExecutor`, verify correct tmux commands generated and output parsed into `Mux*` models.

**Dependencies:** Seed commit on main. Uses existing `lib/services/tmux/tmux_commands.dart` and `lib/services/tmux/tmux_parser.dart` (read-only).

---

### Agent 2 — SshExecutor Implementation

**Model:** Haiku

**Owns:**
- `lib/services/mux/ssh_executor.dart`
- `test/services/mux/ssh_executor_test.dart`

**Work:**
- Implement `CommandExecutor` by wrapping existing `SshClient`
- `execute()` delegates to `SshClient.exec()` or `execPersistent()`
- `shell()` delegates to `SshClient.startShell()`
- `dispose()` delegates to `SshClient.disconnect()`
- Does NOT modify existing `SshClient` — wraps it

**Tests:** Mock `SshClient`, verify delegation.

**Dependencies:** Seed commit on main. Uses existing `lib/services/ssh/ssh_client.dart` (read-only).

---

### Agent 3 — PsmuxBackend + Detection

**Model:** Sonnet

**Owns:**
- `lib/services/mux/psmux_backend.dart`
- `lib/services/mux/mux_detector.dart`
- `test/services/mux/psmux_backend_test.dart`
- `test/services/mux/mux_detector_test.dart`

**Work:**
- `PsmuxBackend` implements `MuxBackend` — delegates most methods to an internal `TmuxBackend` instance (psmux is command-compatible with tmux)
- Override `name` → `"psmux"`
- Override `getNestedBackend()` — probe for tmux inside WSL panes by running `wsl -d <distro> -- tmux ls` via the executor
- `MuxDetector`: auto-detect backend type by running `psmux -V` vs `tmux -V` via `CommandExecutor`, return `MuxType`

**Tests:** Verify psmux delegates correctly to TmuxBackend, detection logic returns correct `MuxType` for various version outputs.

**Dependencies:** Seed commit on main. Imports `TmuxBackend` from Agent 1's file (interface only — works against the abstract contract).

**Note:** Agent 3 depends on `TmuxBackend` existing but only uses it through the `MuxBackend` interface. At integration time, the real `TmuxBackend` from Agent 1 will be wired in. During development, Agent 3 can create a minimal stub or mock.

---

### Agent 4 — WslBridgeExecutor + MuxNode

**Model:** Sonnet

**Owns:**
- `lib/services/mux/wsl_executor.dart`
- `lib/services/mux/mux_node.dart`
- `test/services/mux/wsl_executor_test.dart`
- `test/services/mux/mux_node_test.dart`

**Work:**
- `WslBridgeExecutor` implements `CommandExecutor` — wraps commands with `wsl -d <distro> -- <command>`
- `MuxNode` — tree structure for nested multiplexer navigation:
 ```dart
 class MuxNode {
 final MuxBackend backend;
 final CommandExecutor executor;
 final MuxNode? parent;
 final List<MuxNode> children;
 final String? paneTarget; // which parent pane hosts this node
 }
 ```
- Navigation helpers: `findRoot()`, `breadcrumbPath()` (returns `List<MuxNode>`), `attachChild()`

**Tests:** Tree construction, WSL command wrapping (`wsl -d Ubuntu -- tmux ls` etc.), breadcrumb path generation.

**Dependencies:** Seed commit on main. Uses only abstract interfaces (`MuxBackend`, `CommandExecutor`).

---

### Agent 5 — UI Changes

**Model:** Opus

**Owns:** Modifications to existing files across `lib/providers/`, `lib/screens/`, `lib/models/`

**Work:**
1. **Connection model update** — add fields to `Connection` in `lib/providers/connection_provider.dart`:
 - `MuxType muxType` (default: `auto`)
 - `TransportType transport` (default: `ssh`)
 - `String? wslDistro`
 - `bool nestedTmux` (default: `false`)
 - Update JSON serialization, `copyWith`, and `SharedPreferences` persistence

2. **Connection form** — update `lib/screens/connections/connection_form_screen.dart`:
 - Add dropdown for `MuxType` (tmux / psmux / auto)
 - Add dropdown for `TransportType` (SSH / WSL Bridge)
 - Conditionally show `wslDistro` field when transport is `wslBridge`
 - Conditionally show `nestedTmux` toggle

3. **MuxProvider** — create `lib/providers/mux_provider.dart`:
 - Replaces direct tmux calls in `TmuxProvider` with `MuxBackend` calls
 - State holds `MuxNode` tree for nested navigation
 - Exposes `currentNode`, `navigateToChild()`, `navigateToParent()`, `breadcrumbPath`

4. **BreadcrumbHeader widget** — create `lib/widgets/breadcrumb_header.dart`:
 - Displays `[psmux:work] → [wsl:Ubuntu] → [tmux:dev] → window:editor → pane:0`
 - Each segment is tappable, navigates to that level via `MuxProvider`

5. **Terminal screen** — update `lib/screens/terminal/terminal_screen.dart`:
 - Replace `TmuxProvider` usage with `MuxProvider`
 - Add `BreadcrumbHeader` to the app bar area

**No new tests** — integration agent verifies with `flutter analyze`. UI testing deferred to polish phase.

**Dependencies:** Seed commit on main. This agent touches the most files and has the highest merge risk, hence Opus.

---

## Phase 2: Integration Agent

**Model:** Opus

**Work:**

1. **Merge** — merge all 5 worktree branches into main, one at a time, resolving conflicts:
 - Expected conflict hotspots:
 - `pubspec.yaml` (if any agent adds dependencies)
 - Provider imports in screens
 - `lib/services/mux/` barrel exports (if multiple agents create them)
 - Resolution strategy: accept all new files, manually resolve import conflicts

2. **Wire end-to-end flow:**
 - `ConnectionScreen` → create appropriate `CommandExecutor` based on `TransportType`
 - `CommandExecutor` → create appropriate `MuxBackend` based on `MuxType` (or auto-detect via `MuxDetector`)
 - `MuxBackend` → feed into `MuxProvider`
 - `MuxProvider` → drive terminal screen + breadcrumb UI

3. **Verify:**
 - `flutter analyze` — zero warnings/errors
 - `flutter test` — all existing + new tests pass
 - Fix any issues found

4. **Report** — summarize merge decisions and any architectural adjustments for user review

---

## File Ownership Matrix

| File / Directory | Seed | A1 | A2 | A3 | A4 | A5 | Integration |
|---|---|---|---|---|---|---|---|
| `lib/services/mux/mux_backend.dart` | W | R | - | R | R | R | R |
| `lib/services/mux/mux_models.dart` | W | R | - | R | R | R | R |
| `lib/services/mux/command_executor.dart` | W | R | R | R | R | R | R |
| `lib/services/mux/mux_types.dart` | W | - | - | R | - | R | R |
| `lib/services/mux/tmux_backend.dart` | - | W | - | R | - | - | R |
| `lib/services/mux/ssh_executor.dart` | - | - | W | - | - | - | R |
| `lib/services/mux/psmux_backend.dart` | - | - | - | W | - | - | R |
| `lib/services/mux/mux_detector.dart` | - | - | - | W | - | - | R |
| `lib/services/mux/wsl_executor.dart` | - | - | - | - | W | - | R |
| `lib/services/mux/mux_node.dart` | - | - | - | - | W | - | R |
| `lib/providers/connection_provider.dart` | - | - | - | - | - | W | R |
| `lib/providers/mux_provider.dart` | - | - | - | - | - | W | R |
| `lib/screens/connections/*` | - | - | - | - | - | W | R |
| `lib/screens/terminal/*` | - | - | - | - | - | W | R |
| `lib/widgets/breadcrumb_header.dart` | - | - | - | - | - | W | R |
| `test/services/mux/*` | - | W | W | W | W | - | R |

W = writes, R = reads, - = no access

No two agents write to the same file. This is the key design constraint that makes 5-way parallel execution viable.

---

## Model Assignment Summary

| Agent | Model | Rationale |
|---|---|---|
| Seed | Sonnet | Straightforward interface generation from spec |
| Agent 1 (TmuxBackend) | Sonnet | Mechanical refactor, wrapping existing code |
| Agent 2 (SshExecutor) | Haiku | Simplest agent — thin delegation wrapper |
| Agent 3 (PsmuxBackend) | Sonnet | Delegation + detection logic, moderate complexity |
| Agent 4 (WslBridge+MuxNode) | Sonnet | Novel but well-scoped data structures |
| Agent 5 (UI) | Opus | Most files, cross-cutting concerns, highest judgment needed |
| Integration | Opus | 5-way merge reasoning, end-to-end wiring |

---

## Risks & Mitigations

**Risk: 5-way merge conflicts**
Mitigated by strict file ownership — no two agents write to the same file. Expected conflicts limited to imports and barrel files.

**Risk: Agent 3 depends on Agent 1's TmuxBackend**
Mitigated by coding against the abstract `MuxBackend` interface. Agent 3 mocks/stubs during development; integration agent wires the real implementation.

**Risk: Agent 5 (UI) scope creep**
Agent 5 has the broadest scope. Mitigated by using Opus and keeping clear boundaries: model updates + form fields + new provider + breadcrumb widget + terminal screen wiring. No new screens.

**Risk: psmux command output diverges from tmux**
`PsmuxBackend` delegates to `TmuxBackend` for shared logic. Divergences are isolated to overrides. A compatibility test suite (future work) will catch edge cases.

**Risk: WSL bridge latency**
Each `wsl -d <distro> -- <command>` spawns a process. Future optimization: keep a persistent WSL shell open (similar to `PersistentShell` for SSH). Out of scope for this spec.
