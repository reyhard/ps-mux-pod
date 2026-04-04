# Terminal PTY Stream & xterm.dart Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the polling-based terminal (capture-pane + custom AnsiTextView) with a real-time PTY stream via `tmux attach` rendered by xterm.dart, and fix the battery optimization prompt annoyance.

**Architecture:** SSH opens a PTY shell that runs `tmux attach-session`. The shell's stdout streams into xterm.dart's `Terminal` model for real-time rendering. User input from xterm.dart flows back through the PTY. A separate side channel (existing persistent shell) handles session/pane navigation commands. The `MuxBackend` interface gains an `attachPty()` method so the terminal screen is backend-agnostic.

**Tech Stack:** Flutter 3.24+, Dart 3.x, xterm (pub.dev), dartssh2, flutter_riverpod

**User Verification:** NO — no user verification required

---

## Subagent Execution Strategy

```
Batch 0 (seed, sequential): Task 0 — Foundation
Batch 1 (3 parallel subagents): Task 1 (SSH + Backend PTY) | Task 2 (Special Keys VT100) | Task 3 (Battery Setting)
Batch 2 (1 subagent): Task 4 — Terminal Screen Rewrite
Batch 3 (1 subagent): Task 5 — Dead Code Removal & Cleanup
```

**Task 0** must complete first — it adds the xterm dependency and defines the interfaces that Tasks 1-3 build on.

**Tasks 1, 2, 3** are fully independent and run as 3 parallel subagents:
- **Subagent A** (Task 1): SSH client + SshExecutor + TmuxBackend PTY changes
- **Subagent B** (Task 2): Special keys bar VT100 escape sequence mapping
- **Subagent C** (Task 3): Battery optimization setting

**Task 4** depends on Tasks 1-3 completing. It's the core rewrite of terminal_screen.dart.

**Task 5** depends on Task 4. Removes all dead code left behind by the rewrite.

---

## File Map

### New files:
- `lib/services/mux/mux_pty_session.dart` — Bidirectional PTY session model

### Modified files:
- `pubspec.yaml` — Add xterm dependency
- `lib/services/mux/command_executor.dart` — Extend shell() to return InteractiveShell
- `lib/services/mux/ssh_executor.dart` — Implement InteractiveShell with dartssh2
- `lib/services/mux/mux_backend.dart` — Add attachPty() method
- `lib/services/mux/tmux_backend.dart` — Implement attachPty() for tmux
- `lib/services/ssh/ssh_client.dart` — Add openPtyShell(), remove polling shell, remove execInput()
- `lib/widgets/special_keys_bar.dart` — Replace tmux key names with VT100 escape sequences
- `lib/providers/settings_provider.dart` — Add askBatteryOptimization setting
- `lib/screens/settings/settings_screen.dart` — Add battery optimization toggle
- `lib/services/background/foreground_task_service.dart` — Check setting before prompting
- `lib/screens/terminal/terminal_screen.dart` — Full rewrite around TerminalView + PTY stream

### Files to delete (Task 5):
- `lib/screens/terminal/widgets/ansi_text_view.dart`
- `lib/services/terminal/ansi_parser.dart`
- `lib/services/terminal/terminal_diff.dart`
- `lib/services/terminal/scrollback_buffer.dart`
- `lib/services/terminal/font_calculator.dart`
- `lib/providers/terminal_display_provider.dart`

---

## Task 0: Foundation — xterm Dependency & Interface Definitions

**Goal:** Add the xterm package, define the `InteractiveShell` and `MuxPtySession` models, and update the `CommandExecutor`/`MuxBackend` interfaces.

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/mux/mux_pty_session.dart`
- Modify: `lib/services/mux/command_executor.dart`
- Modify: `lib/services/mux/mux_backend.dart`

**Acceptance Criteria:**
- [ ] xterm package added to pubspec.yaml and `flutter pub get` succeeds
- [ ] `MuxPtySession` model defined with stdout stream, write, resize, close
- [ ] `CommandExecutor` has `openInteractiveShell()` returning `InteractiveShell`
- [ ] `MuxBackend` has `attachPty()` returning `Future<MuxPtySession>`
- [ ] `flutter analyze` passes with no errors (warnings about unimplemented methods are expected)

**Verify:** `cd o:/Projects/ps-mux-pod && flutter pub get && flutter analyze`

**Steps:**

- [ ] **Step 1: Add xterm dependency**

In `pubspec.yaml`, add under dependencies:

```yaml
 # Terminal emulator widget
 xterm: ^4.0.0
```

Run: `flutter pub get`

- [ ] **Step 2: Create MuxPtySession model**

Create `lib/services/mux/mux_pty_session.dart`:

```dart
import 'dart:typed_data';

/// Bidirectional PTY session for real-time terminal I/O.
///
/// Returned by [MuxBackend.attachPty] and consumed by the terminal screen.
/// Each backend (tmux, psmux) produces this by opening an interactive shell
/// and running its attach command.
class MuxPtySession {
 MuxPtySession({
 required this.stdout,
 required this.write,
 required this.resize,
 required this.close,
 });

 /// Stream of raw bytes from the PTY (terminal output).
 final Stream<List<int>> stdout;

 /// Write raw bytes to the PTY (user input).
 final void Function(Uint8List data) write;

 /// Resize the PTY terminal dimensions.
 final void Function(int cols, int rows) resize;

 /// Close the PTY session and release resources.
 final Future<void> Function() close;
}
```

- [ ] **Step 3: Define InteractiveShell in CommandExecutor**

Replace the existing `shell()` method in `lib/services/mux/command_executor.dart`:

```dart
import 'dart:typed_data';

/// A bidirectional interactive shell session.
class InteractiveShell {
 InteractiveShell({
 required this.stdout,
 required this.write,
 required this.resize,
 required this.close,
 });

 final Stream<List<int>> stdout;
 final void Function(Uint8List data) write;
 final void Function(int cols, int rows) resize;
 final Future<void> Function() close;
}

/// Abstract interface for executing commands on a target system.
abstract class CommandExecutor {
 /// Execute a command and return its output.
 Future<String> execute(String command);

 /// Open an interactive terminal session with bidirectional I/O.
 Future<InteractiveShell> openInteractiveShell({
 int cols = 80,
 int rows = 24,
 });

 /// Release resources held by this executor.
 Future<void> dispose();
}
```

- [ ] **Step 4: Add attachPty to MuxBackend interface**

In `lib/services/mux/mux_backend.dart`, add the import and method:

```dart
import 'mux_models.dart';
import 'mux_pty_session.dart';

abstract class MuxBackend {
 String get name;

 // --- Sessions ---
 Future<List<MuxSession>> listSessions();
 Future<MuxSession> newSession({String? name});
 Future<void> killSession(String sessionId);
 Future<void> attachSession(String sessionId);

 // --- Windows ---
 Future<List<MuxWindow>> listWindows(String sessionId);
 Future<MuxWindow> newWindow(String sessionId, {String? name});
 Future<void> selectWindow(String sessionId, int index);

 // --- Panes ---
 Future<List<MuxPane>> listPanes(String windowTarget);
 Future<void> splitPane(String target, {bool horizontal = true});
 Future<void> selectPane(String target, int index);

 // --- I/O ---
 Future<String> capturePane(String target);
 Future<void> sendKeys(String target, String keys);

 // --- PTY Stream ---

 /// Open a real-time PTY session attached to the given session.
 /// Returns a bidirectional stream for terminal I/O.
 Future<MuxPtySession> attachPty(String sessionId);

 // --- Nesting ---
 Future<MuxBackend?> getNestedBackend(String paneTarget);
}
```

- [ ] **Step 5: Add stub attachPty to PsmuxBackend**

PsmuxBackend also implements MuxBackend. Add a stub so it compiles:

In `lib/services/mux/psmux_backend.dart`, add:

```dart
@override
Future<MuxPtySession> attachPty(String sessionId) {
 throw UnimplementedError('PTY stream not yet supported for psmux');
}
```

Also add the `openInteractiveShell()` stub to any other CommandExecutor implementations (e.g., WslBridgeExecutor if it exists):

```dart
@override
Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
 throw UnimplementedError('Interactive shell not yet supported for this executor');
}
```

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/mux/mux_pty_session.dart lib/services/mux/command_executor.dart lib/services/mux/mux_backend.dart lib/services/mux/psmux_backend.dart
git commit -m "feat: add xterm dependency and PTY stream interfaces"
```

---

## Task 1: SSH Client PTY Channel + Backend Implementation

**Goal:** Implement `openInteractiveShell()` in SshExecutor and `attachPty()` in TmuxBackend, providing the real-time PTY stream that the terminal screen will consume. Remove the polling shell and `execInput()` from SshClient since they become unnecessary.

**Files:**
- Modify: `lib/services/ssh/ssh_client.dart` — Add `openPtyShell()`, remove `_inputShell`, `execInput()`, `_pollPaneContent`-related code
- Modify: `lib/services/mux/ssh_executor.dart` — Implement `openInteractiveShell()`
- Modify: `lib/services/mux/tmux_backend.dart` — Implement `attachPty()`

**Acceptance Criteria:**
- [ ] `SshClient.openPtyShell()` opens a new SSH shell session with PTY and returns it
- [ ] `SshExecutor.openInteractiveShell()` wraps `openPtyShell()` into `InteractiveShell`
- [ ] `TmuxBackend.attachPty()` opens shell, writes `tmux attach-session -t <id>`, returns `MuxPtySession`
- [ ] `_inputShell` and `execInput()` removed from SshClient
- [ ] Existing `_persistentShell` kept for side-channel commands (tree refresh, pane select)
- [ ] `flutter analyze` passes

**Verify:** `flutter analyze`

**Steps:**

- [ ] **Step 1: Add openPtyShell() to SshClient**

In `lib/services/ssh/ssh_client.dart`, add a new method that opens a fresh SSH shell session with PTY configuration. This is separate from the existing `_session` (used by `startShell()`) and `_persistentShell` (used for side-channel commands).

```dart
import 'dart:typed_data';

/// Opens a new PTY shell session for interactive terminal use.
///
/// Unlike [startShell] (which manages the single _session field),
/// this creates an independent shell that the caller manages.
/// Used by SshExecutor to provide PTY streams for terminal attachment.
Future<SSHSession> openPtyShell({
 int cols = 80,
 int rows = 24,
 String termType = 'xterm-256color',
}) async {
 if (_client == null) {
 throw SshClientException('Not connected');
 }
 final session = await _client!.shell(
 pty: SSHPtyConfig(
 type: termType,
 width: cols,
 height: rows,
 ),
 );
 return session;
}
```

- [ ] **Step 2: Remove _inputShell and execInput()**

In `lib/services/ssh/ssh_client.dart`:

1. Remove the `_inputShell` field (line ~134)
2. Remove `_inputShell` creation from `_startPersistentShell()` (lines ~374-376)
3. Remove `_inputShell` restart from `restartPersistentShell()` (lines ~386-400)
4. Remove the `execInput()` method entirely (lines ~752-780)
5. Remove `_inputShell` disposal from `disconnect()` 
6. Update keep-alive to use `execPersistent()` instead of `execInput()` (line ~540)

The `_persistentShell` stays — it's needed for the side channel (tree refresh, pane selection).

- [ ] **Step 3: Implement openInteractiveShell() in SshExecutor**

Replace the old `shell()` method in `lib/services/mux/ssh_executor.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import '../ssh/ssh_client.dart';
import 'command_executor.dart';

class SshExecutor implements CommandExecutor {
 final SshClient _sshClient;

 SshExecutor(this._sshClient);

 @override
 Future<String> execute(String command) async {
 return _sshClient.execPersistent(command);
 }

 @override
 Future<InteractiveShell> openInteractiveShell({
 int cols = 80,
 int rows = 24,
 }) async {
 final session = await _sshClient.openPtyShell(
 cols: cols,
 rows: rows,
 );

 return InteractiveShell(
 stdout: session.stdout,
 write: (Uint8List data) => session.write(data),
 resize: (int cols, int rows) => session.resizeTerminal(cols, rows),
 close: () async => session.close(),
 );
 }

 @override
 Future<void> dispose() async {
 await _sshClient.disconnect();
 }
}
```

- [ ] **Step 4: Implement attachPty() in TmuxBackend**

In `lib/services/mux/tmux_backend.dart`, add:

```dart
import 'dart:convert';
import 'mux_pty_session.dart';

// Inside TmuxBackend class:

@override
Future<MuxPtySession> attachPty(String sessionId) async {
 final shell = await _executor.openInteractiveShell();

 // Send the tmux attach command through the PTY
 shell.write(utf8.encode('tmux attach-session -t $sessionId\n'));

 return MuxPtySession(
 stdout: shell.stdout,
 write: shell.write,
 resize: shell.resize,
 close: shell.close,
 );
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/services/ssh/ssh_client.dart lib/services/mux/ssh_executor.dart lib/services/mux/tmux_backend.dart
git commit -m "feat: implement PTY stream in SSH client and TmuxBackend"
```

---

## Task 2: Special Keys Bar — VT100 Escape Sequences

**Goal:** Replace tmux key name format (`Enter`, `Escape`, `C-c`, `PPage`, etc.) with VT100/xterm escape sequences so the special keys bar writes directly to the PTY stream.

**Files:**
- Modify: `lib/widgets/special_keys_bar.dart`

**Acceptance Criteria:**
- [ ] All on-screen button key presses produce VT100 escape sequences as `String`
- [ ] Modifier combinations (Ctrl+letter) produce correct control characters
- [ ] `onSpecialKeyPressed` callback signature changes to `void Function(String escapeSequence)`
- [ ] Hardware keyboard handling removed (xterm.dart's TerminalView handles it natively)
- [ ] `flutter analyze` passes

**Verify:** `flutter analyze`

**Steps:**

- [ ] **Step 1: Create VT100 key map**

Replace the tmux key name map (lines ~287-311 in `special_keys_bar.dart`) with VT100 escape sequences. Also replace the modifier application logic.

The new key map (replacing `_specialKeyMap` and modifier logic):

```dart
/// VT100/xterm escape sequences for special keys.
/// These are written directly to the PTY stream.
class Vt100Keys {
 static const escape = '\x1b';
 static const enter = '\r';
 static const tab = '\t';
 static const backspace = '\x7f';
 static const delete = '\x1b[3~';
 static const insert = '\x1b[2~';

 static const up = '\x1b[A';
 static const down = '\x1b[B';
 static const right = '\x1b[C';
 static const left = '\x1b[D';

 static const home = '\x1b[H';
 static const end = '\x1b[F';
 static const pageUp = '\x1b[5~';
 static const pageDown = '\x1b[6~';

 static const f1 = '\x1bOP';
 static const f2 = '\x1bOQ';
 static const f3 = '\x1bOR';
 static const f4 = '\x1bOS';
 static const f5 = '\x1b[15~';
 static const f6 = '\x1b[17~';
 static const f7 = '\x1b[18~';
 static const f8 = '\x1b[19~';
 static const f9 = '\x1b[20~';
 static const f10 = '\x1b[21~';
 static const f11 = '\x1b[23~';
 static const f12 = '\x1b[24~';

 static const backTab = '\x1b[Z'; // Shift+Tab

 /// Convert a letter to its Ctrl+ control character.
 /// Ctrl+A = 0x01, Ctrl+B = 0x02, ..., Ctrl+Z = 0x1A
 static String ctrl(String letter) {
 final code = letter.toUpperCase().codeUnitAt(0) - 0x40;
 return String.fromCharCode(code);
 }

 /// Wrap a key sequence with Alt (Meta) prefix.
 static String alt(String key) => '\x1b$key';
}
```

- [ ] **Step 2: Update _sendSpecialKey to output escape sequences**

Replace the method that builds tmux-format keys (lines ~973-1014) with one that outputs VT100 sequences. The modifier state (`_ctrlPressed`, `_altPressed`) is applied here:

```dart
void _sendSpecialKey(String key) {
 String sequence = key; // Already a VT100 sequence from button tap

 // Apply sticky modifiers
 if (_ctrlPressed && key.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(key)) {
 sequence = Vt100Keys.ctrl(key);
 }
 if (_altPressed) {
 sequence = Vt100Keys.alt(sequence);
 }

 // Reset modifiers after use
 setState(() {
 _ctrlPressed = false;
 _altPressed = false;
 _shiftPressed = false;
 });

 widget.onSpecialKeyPressed(sequence);

 if (widget.hapticFeedback) {
 HapticFeedback.lightImpact();
 }
}
```

- [ ] **Step 3: Update on-screen button definitions**

Replace all button `onPressed` handlers that referenced tmux key names with VT100 constants:

```dart
// Arrow keys row - change from 'Up'/'Down' etc to Vt100Keys constants:
_buildKeyButton('↑', () => _sendSpecialKey(Vt100Keys.up)),
_buildKeyButton('↓', () => _sendSpecialKey(Vt100Keys.down)),
_buildKeyButton('←', () => _sendSpecialKey(Vt100Keys.left)),
_buildKeyButton('→', () => _sendSpecialKey(Vt100Keys.right)),

// Navigation keys row:
_buildKeyButton('PgUp', () => _sendSpecialKey(Vt100Keys.pageUp)),
_buildKeyButton('PgDn', () => _sendSpecialKey(Vt100Keys.pageDown)),
_buildKeyButton('Home', () => _sendSpecialKey(Vt100Keys.home)),
_buildKeyButton('End', () => _sendSpecialKey(Vt100Keys.end)),
_buildKeyButton('Del', () => _sendSpecialKey(Vt100Keys.delete)),
_buildKeyButton('Ins', () => _sendSpecialKey(Vt100Keys.insert)),

// Action keys:
_buildKeyButton('Enter', () => _sendSpecialKey(Vt100Keys.enter)),
_buildKeyButton('Tab', () => _sendSpecialKey(Vt100Keys.tab)),
_buildKeyButton('Esc', () => _sendSpecialKey(Vt100Keys.escape)),
_buildKeyButton('BS', () => _sendSpecialKey(Vt100Keys.backspace)),
```

- [ ] **Step 4: Update _sendLiteralKey for direct character input**

The `_sendLiteralKey` method (lines ~1016-1046) sends literal text. With the PTY approach, literal text is just written as-is. Modifier handling becomes:

```dart
void _sendLiteralKey(String key) {
 String data = key;

 if (_ctrlPressed && key.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(key)) {
 data = Vt100Keys.ctrl(key);
 } else if (_altPressed && key.length == 1) {
 data = Vt100Keys.alt(key);
 }

 setState(() {
 _ctrlPressed = false;
 _altPressed = false;
 _shiftPressed = false;
 });

 widget.onKeyPressed(data);

 if (widget.hapticFeedback) {
 HapticFeedback.lightImpact();
 }
}
```

- [ ] **Step 5: Remove hardware keyboard handling**

Remove `_handleKeyEvent()` (lines ~336-383) and the `HardwareKeyboard.instance.addHandler` / `removeHandler` in `initState` / `dispose`. xterm.dart's `TerminalView` handles hardware keyboard input natively — having both would cause double-input.

Keep the `FocusNode` for the DirectInput TextField, but remove the one used for hardware key interception.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/special_keys_bar.dart
git commit -m "feat: replace tmux key names with VT100 escape sequences in special keys bar"
```

---

## Task 3: Battery Optimization Setting

**Goal:** Add a setting to suppress the battery optimization prompt, and check it in the foreground task service.

**Files:**
- Modify: `lib/providers/settings_provider.dart`
- Modify: `lib/services/background/foreground_task_service.dart`
- Modify: `lib/screens/settings/settings_screen.dart`

**Acceptance Criteria:**
- [ ] New `askBatteryOptimization` setting (bool, default true) in AppSettings
- [ ] Setting persisted via SharedPreferences
- [ ] Toggle visible in settings screen under Connection section
- [ ] `ForegroundTaskService.requestPermissions()` skips battery prompt when setting is false
- [ ] `flutter analyze` passes

**Verify:** `flutter analyze`

**Steps:**

- [ ] **Step 1: Add setting to AppSettings model**

In `lib/providers/settings_provider.dart`, add to the `AppSettings` class:

```dart
// In AppSettings constructor, add:
this.askBatteryOptimization = true,

// Add field:
final bool askBatteryOptimization;

// In copyWith:
bool? askBatteryOptimization,
// ...
askBatteryOptimization: askBatteryOptimization ?? this.askBatteryOptimization,
```

In `SettingsNotifier`, add storage key and setter:

```dart
static const _askBatteryOptimizationKey = 'settings_ask_battery_optimization';

// In _loadSettings(), add:
askBatteryOptimization: prefs.getBool(_askBatteryOptimizationKey) ?? true,

// Add setter:
void setAskBatteryOptimization(bool value) {
 state = state.copyWith(askBatteryOptimization: value);
 _saveSetting(_askBatteryOptimizationKey, value);
}
```

- [ ] **Step 2: Check setting in ForegroundTaskService**

Modify `requestPermissions()` in `lib/services/background/foreground_task_service.dart` to accept the setting value:

```dart
Future<bool> requestPermissions({bool askBatteryOptimization = true}) async {
 if (!Platform.isAndroid) return true;

 // Check notification permission (Android 13+)
 final notificationPermission =
 await FlutterForegroundTask.checkNotificationPermission();
 if (notificationPermission != NotificationPermission.granted) {
 await FlutterForegroundTask.requestNotificationPermission();
 }

 // Only request battery optimization exemption if user hasn't disabled the prompt
 if (askBatteryOptimization) {
 final batteryOptimization =
 await FlutterForegroundTask.isIgnoringBatteryOptimizations;
 if (!batteryOptimization) {
 await FlutterForegroundTask.requestIgnoreBatteryOptimization();
 }
 }

 return await FlutterForegroundTask.checkNotificationPermission() ==
 NotificationPermission.granted;
}
```

Update `startService()` to pass the setting through:

```dart
Future<bool> startService({
 required String connectionName,
 required String host,
 bool askBatteryOptimization = true,
}) async {
 // ... existing init check ...
 final hasPermission = await requestPermissions(
 askBatteryOptimization: askBatteryOptimization,
 );
 // ... rest unchanged ...
}
```

- [ ] **Step 3: Add toggle to settings screen**

In `lib/screens/settings/settings_screen.dart`, add a toggle in the appropriate section. Find the section where other connection-related settings are and add:

```dart
SwitchListTile(
 title: const Text('disabledconfirm'),
 subtitle: const Text('connectiondisabledconfirm'),
 value: settings.askBatteryOptimization,
 onChanged: (value) {
 ref.read(settingsProvider.notifier).setAskBatteryOptimization(value);
 },
),
```

- [ ] **Step 4: Update callers to pass setting**

Find where `startService()` is called (likely in `terminal_screen.dart` or connection setup) and pass the setting value:

```dart
final settings = ref.read(settingsProvider);
await foregroundTaskService.startService(
 connectionName: connection.name,
 host: connection.host,
 askBatteryOptimization: settings.askBatteryOptimization,
);
```

- [ ] **Step 5: Commit**

```bash
git add lib/providers/settings_provider.dart lib/services/background/foreground_task_service.dart lib/screens/settings/settings_screen.dart
git commit -m "feat: add battery optimization prompt setting"
```

---

## Task 4: Terminal Screen Rewrite

**Goal:** Rewrite `terminal_screen.dart` to use xterm.dart's `TerminalView` widget connected to a `MuxPtySession` stream. Remove all polling logic. Keep session drawer, breadcrumb header, special keys bar, and app lifecycle handling.

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart` — Major rewrite

**Acceptance Criteria:**
- [ ] `TerminalView` replaces `AnsiTextView` for terminal rendering
- [ ] PTY stream from `MuxBackend.attachPty()` connected to `Terminal.write()`
- [ ] User input via `Terminal.onOutput` written to PTY
- [ ] Resize via `Terminal.onResize` forwarded to PTY `resize()`
- [ ] Session drawer still works — pane/window/session switching via side channel
- [ ] Session switching via `switch-client` sent through side channel
- [ ] Reconnection reopens PTY and reattaches
- [ ] Special keys bar writes VT100 escape sequences to PTY
- [ ] Enter Command dialog writes text to PTY
- [ ] App lifecycle pause/resume handled
- [ ] No polling code remains
- [ ] `flutter analyze` passes

**Verify:** `flutter analyze`

**Steps:**

- [ ] **Step 1: Replace state variables**

Remove polling-related state and add PTY/terminal state. The key replacements:

```dart
// REMOVE these:
// _ansiTextViewKey, _viewNotifier, _pollTimer, _isPolling,
// _currentPollingInterval, _terminalMode, _scrollModeSource,
// _scrollbackBuffer, _terminalScrollController (xterm has its own)

// ADD these:
late final Terminal _terminal;
MuxPtySession? _ptySession;
StreamSubscription<List<int>>? _ptySubscription;
```

Initialize the terminal in the class body or initState:

```dart
@override
void initState() {
 super.initState();
 WidgetsBinding.instance.addObserver(this);
 _terminal = Terminal(maxLines: 10000);

 // Terminal output (user keystrokes) → PTY
 _terminal.onOutput = (String data) {
 _ptySession?.write(Uint8List.fromList(utf8.encode(data)));
 };

 // Terminal resize → PTY resize
 _terminal.onResize = (int width, int height, int pixelWidth, int pixelHeight) {
 _ptySession?.resize(width, height);
 };

 WidgetsBinding.instance.addPostFrameCallback((_) {
 _setupListeners();
 _connectAndSetup();
 _applyKeepScreenOn();
 });
}
```

- [ ] **Step 2: Implement _connectAndSetup with PTY attachment**

Replace the current connection flow (which starts polling after connect) with one that opens a PTY stream:

```dart
Future<void> _connectAndSetup() async {
 setState(() {
 _isConnecting = true;
 _connectionError = null;
 });

 try {
 // 1. SSH connect (existing flow)
 final sshNotifier = ref.read(sshProvider(widget.connection.id).notifier);
 await sshNotifier.connect(widget.connection);

 // 2. Detect mux backend (existing flow)
 await _detectAndSetupMuxBackend();

 // 3. Start foreground service with battery setting
 final settings = ref.read(settingsProvider);
 await _foregroundTaskService.startService(
 connectionName: widget.connection.name,
 host: widget.connection.host,
 askBatteryOptimization: settings.askBatteryOptimization,
 );

 // 4. Attach PTY to tmux session
 final muxBackend = ref.read(muxProvider).backend;
 if (muxBackend != null) {
 await _attachPty(muxBackend);
 }

 // 5. Start tree refresh (side channel, same as before)
 _startTreeRefresh();

 setState(() { _isConnecting = false; });
 } catch (e) {
 setState(() {
 _isConnecting = false;
 _connectionError = e.toString();
 });
 }
}

Future<void> _attachPty(MuxBackend backend) async {
 // Close existing PTY if any
 await _closePty();

 final sessionName = ref.read(tmuxProvider).activeSession?.name;
 if (sessionName == null) return;

 _ptySession = await backend.attachPty(sessionName);

 // PTY stdout → terminal
 _ptySubscription = _ptySession!.stdout.listen(
 (data) {
 _terminal.write(String.fromCharCodes(data));
 },
 onError: (error) {
 debugPrint('PTY stream error: $error');
 _handleDisconnect();
 },
 onDone: () {
 debugPrint('PTY stream closed');
 _handleDisconnect();
 },
 );
}

Future<void> _closePty() async {
 await _ptySubscription?.cancel();
 _ptySubscription = null;
 await _ptySession?.close();
 _ptySession = null;
}
```

- [ ] **Step 3: Replace build method — TerminalView instead of AnsiTextView**

The core of the build method changes from the `ValueListenableBuilder<_TerminalViewData>` + `AnsiTextView` to:

```dart
// In the body of the Scaffold, replace the AnsiTextView section with:
TerminalView(
 _terminal,
 style: TerminalStyle(
 fontSize: ref.watch(settingsProvider).fontSize * _zoomScale,
 fontFamily: ref.watch(settingsProvider).fontFamily,
 ),
 autofocus: true,
 onSecondaryTapDown: (details, offset) {
 // Context menu for copy/paste if needed
 },
),
```

Keep the surrounding `Stack` structure with:
- Breadcrumb header (top) — unchanged
- TerminalView (center, expanded)
- Special keys bar (bottom) — same widget, new callback wiring
- Scroll-to-bottom button — may not be needed (xterm.dart has built-in scrollback)
- Connection error overlay — unchanged
- Loading overlay — unchanged

- [ ] **Step 4: Wire special keys bar to PTY**

Update the SpecialKeysBar callbacks to write directly to the PTY:

```dart
SpecialKeysBar(
 onKeyPressed: (String key) {
 // Literal text input — write directly to PTY
 _ptySession?.write(Uint8List.fromList(utf8.encode(key)));
 },
 onSpecialKeyPressed: (String escapeSequence) {
 // VT100 escape sequence — write directly to PTY
 _ptySession?.write(Uint8List.fromList(utf8.encode(escapeSequence)));
 },
 onInputTap: _showInputDialog,
 directInputEnabled: _directInputEnabled,
 onDirectInputToggle: () {
 ref.read(settingsProvider.notifier).toggleDirectInput();
 setState(() {
 _directInputEnabled = !_directInputEnabled;
 });
 },
),
```

- [ ] **Step 5: Update Enter Command dialog**

The input dialog (`_showInputDialog` / `_sendKey`) currently sends text via `tmux send-keys -l`. Change to write directly to PTY:

```dart
void _sendCommandText(String text) {
 if (_ptySession == null) {
 _inputQueue.enqueue(text);
 return;
 }
 _ptySession!.write(Uint8List.fromList(utf8.encode(text)));
}
```

Update the dialog's Execute button to call `_sendCommandText(text + '\n')` instead of the old tmux send-keys flow.

- [ ] **Step 6: Update session/pane navigation**

Keep the session drawer and navigation methods. They use the side channel (MuxBackend methods via CommandExecutor.execute). The key changes:

For `_selectPane()`:
```dart
Future<void> _selectPane(String paneId) async {
 final backend = ref.read(muxProvider).backend;
 if (backend == null) return;

 // Side channel: select pane
 await backend.selectPane(paneId, 0); // or appropriate index
 // tmux redraws the attached session automatically — PTY stream reflects the change
}
```

For session switching, use the side channel (`switch-client` is a tmux CLI command, not something typed inside an attached session):
```dart
Future<void> _selectSession(String sessionName) async {
 // switch-client via side channel — tmux redraws the attached PTY automatically
 final sshClient = ref.read(sshProvider(widget.connection.id)).client;
 if (sshClient != null) {
 await sshClient.execPersistent('tmux switch-client -t $sessionName');
 }
 
 // Update local state
 ref.read(tmuxProvider.notifier).setActiveSession(sessionName);
}
```

- [ ] **Step 7: Update reconnection flow**

Replace the polling-based reconnection with PTY reattachment:

```dart
void _onReconnectSuccess() {
 if (_isDisposed) return;

 // Re-detect backend and reattach PTY
 _detectAndSetupMuxBackend().then((_) {
 final backend = ref.read(muxProvider).backend;
 if (backend != null) {
 _attachPty(backend);
 }
 _startTreeRefresh();
 _flushInputQueue();
 });

 setState(() {});
}
```

- [ ] **Step 8: Update app lifecycle handling**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
 switch (state) {
 case AppLifecycleState.paused:
 case AppLifecycleState.inactive:
 case AppLifecycleState.hidden:
 // PTY stream stays open (SSH connection maintained by foreground service)
 // Just disable wakelock
 WakelockPlus.disable();
 break;
 case AppLifecycleState.resumed:
 _applyKeepScreenOn();
 // PTY stream auto-resumes — no action needed
 break;
 default:
 break;
 }
}
```

- [ ] **Step 9: Update dispose**

```dart
@override
void dispose() {
 _isDisposed = true;
 WidgetsBinding.instance.removeObserver(this);
 WakelockPlus.disable();
 _closePty();
 _treeRefreshTimer?.cancel();
 // Close Riverpod subscriptions (same as before)
 _sshSub?.close();
 _tmuxSub?.close();
 _settingsSub?.close();
 _networkSub?.close();
 super.dispose();
}
```

- [ ] **Step 10: Remove all polling code**

Delete these methods/fields from terminal_screen.dart:
- `_TerminalViewData` class
- `_viewNotifier`
- `_pollTimer`, `_isPolling`, `_currentPollingInterval`
- `_startPolling()`, `_scheduleNextPoll()`, `_pollPaneContent()`
- `_boostPolling()`, `_updatePollingInterval()`
- `_scheduleUpdate()`, `_applyBufferedUpdate()`
- `_scrollModeSource`, `_terminalMode` (xterm.dart handles scroll natively)
- `_scrollbackBuffer`, `_onScrollTopReached()`
- `_ansiTextViewKey`, `_terminalScrollController`
- All references to `AnsiTextView`, `AnsiTextViewState`

- [ ] **Step 11: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "feat: rewrite terminal screen with xterm.dart and PTY stream"
```

---

## Task 5: Dead Code Removal & Cleanup

**Goal:** Delete files that are no longer used after the terminal rewrite and clean up any remaining imports.

**Files:**
- Delete: `lib/screens/terminal/widgets/ansi_text_view.dart`
- Delete: `lib/services/terminal/ansi_parser.dart`
- Delete: `lib/services/terminal/terminal_diff.dart`
- Delete: `lib/services/terminal/scrollback_buffer.dart`
- Delete: `lib/services/terminal/font_calculator.dart`
- Delete: `lib/providers/terminal_display_provider.dart`
- Modify: Any files that import the deleted files (clean up imports)

**Acceptance Criteria:**
- [ ] All listed files deleted
- [ ] No remaining imports reference deleted files
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter build apk --debug` succeeds

**Verify:** `flutter analyze && flutter build apk --debug`

**Steps:**

- [ ] **Step 1: Delete dead files**

```bash
rm lib/screens/terminal/widgets/ansi_text_view.dart
rm lib/services/terminal/ansi_parser.dart
rm lib/services/terminal/terminal_diff.dart
rm lib/services/terminal/scrollback_buffer.dart
rm lib/services/terminal/font_calculator.dart
rm lib/providers/terminal_display_provider.dart
```

- [ ] **Step 2: Find and fix broken imports**

Search for any remaining imports of deleted files:

```bash
grep -r "ansi_text_view\|ansi_parser\|terminal_diff\|scrollback_buffer\|font_calculator\|terminal_display_provider" lib/
```

Remove all matching import statements from the files that reference them.

- [ ] **Step 3: Check for unused dependencies**

After the rewrite, check if any packages in `pubspec.yaml` are no longer needed. The `google_fonts` package may no longer be needed if xterm.dart handles fonts differently — verify and remove if unused.

- [ ] **Step 4: Run analysis and build**

```bash
flutter analyze
flutter build apk --debug
```

Fix any issues found.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove dead polling code and unused terminal files"
```

---

## Dependency Graph

```
Task 0 (Foundation)
 ├── Task 1 (SSH + Backend PTY) ─┐
 ├── Task 2 (Special Keys VT100) ─┼── Task 4 (Terminal Screen Rewrite) ── Task 5 (Dead Code)
 └── Task 3 (Battery Setting) ─┘
```
