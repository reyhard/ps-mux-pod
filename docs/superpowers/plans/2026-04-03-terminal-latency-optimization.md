# Terminal Latency Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce terminal display latency from 2000+ms to <200ms by eliminating per-poll overhead in the capture-pane → render pipeline.

**Architecture:** Replace the current "capture 1000 lines every poll" model with a visible-area-only poll + client-side scrollback buffer. Send keystrokes via the persistent shell (no new SSH channel per keystroke). Add a dedicated input shell to eliminate serialization between polling and key sends. Trigger immediate polls after keystrokes instead of waiting for the next interval.

**Tech Stack:** Dart/Flutter, dartssh2, PersistentShell, tmux capture-pane

**User Verification:** YES — user confirms latency improvement on real device after implementation.

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `lib/services/terminal/scrollback_buffer.dart` | Client-side scrollback ring buffer | Create |
| `lib/services/ssh/ssh_client.dart` | SSH client — add second persistent shell for input | Modify |
| `lib/services/ssh/persistent_shell.dart` | No changes needed | — |
| `lib/screens/terminal/terminal_screen.dart` | Poll loop, keystroke sending, scrollback integration | Modify |
| `lib/services/tmux/tmux_commands.dart` | No changes needed (already has `capturePaneVisible`) | — |
| `test/services/terminal/scrollback_buffer_test.dart` | Scrollback buffer unit tests | Create |
| `test/services/ssh/ssh_client_input_shell_test.dart` | Input shell unit tests | Create |

---

### Task 0: Create scrollback buffer service

**Goal:** Build a ring buffer that accumulates terminal history client-side, so scrolling reads from local memory instead of re-fetching 1000 lines every poll.

**Files:**
- Create: `lib/services/terminal/scrollback_buffer.dart`
- Test: `test/services/terminal/scrollback_buffer_test.dart`

**Acceptance Criteria:**
- [ ] Ring buffer stores lines up to a configurable max (default 10,000)
- [ ] `appendNewContent(visibleLines)` detects lines that scrolled off the top and moves them to the buffer
- [ ] `getScrollbackRange(start, end)` returns lines from the buffer for scroll-up
- [ ] `seedHistory(lines)` does a one-time bulk load of existing scrollback
- [ ] `clear()` resets the buffer (for pane switch)
- [ ] Old lines are evicted when max capacity is reached

**Verify:** `flutter test test/services/terminal/scrollback_buffer_test.dart` → all pass

**Steps:**

- [ ] **Step 1: Write failing tests**

```dart
// test/services/terminal/scrollback_buffer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:muxpod/services/terminal/scrollback_buffer.dart';

void main() {
 group('ScrollbackBuffer', () {
 late ScrollbackBuffer buffer;

 setUp(() {
 buffer = ScrollbackBuffer(maxLines: 100);
 });

 test('starts empty', () {
 expect(buffer.lineCount, 0);
 expect(buffer.getRange(0, 10), isEmpty);
 });

 test('appendNewContent detects scrolled-off lines', () {
 // First frame: 3 visible lines
 buffer.appendNewContent(['line1', 'line2', 'line3']);
 expect(buffer.lineCount, 0); // nothing scrolled off yet

 // Second frame: line1 scrolled off, line4 appeared
 buffer.appendNewContent(['line2', 'line3', 'line4']);
 expect(buffer.lineCount, 1);
 expect(buffer.getRange(0, 1), ['line1']);
 });

 test('appendNewContent handles bulk scroll (multiple lines scroll off)', () {
 buffer.appendNewContent(['a', 'b', 'c', 'd']);
 buffer.appendNewContent(['c', 'd', 'e', 'f']);
 expect(buffer.lineCount, 2);
 expect(buffer.getRange(0, 2), ['a', 'b']);
 });

 test('appendNewContent handles complete content change', () {
 buffer.appendNewContent(['a', 'b', 'c']);
 buffer.appendNewContent(['x', 'y', 'z']);
 // All previous lines scrolled off
 expect(buffer.lineCount, 3);
 expect(buffer.getRange(0, 3), ['a', 'b', 'c']);
 });

 test('seedHistory bulk loads existing scrollback', () {
 buffer.seedHistory(['old1', 'old2', 'old3']);
 expect(buffer.lineCount, 3);
 expect(buffer.getRange(0, 3), ['old1', 'old2', 'old3']);
 });

 test('evicts old lines when max capacity reached', () {
 final small = ScrollbackBuffer(maxLines: 5);
 small.seedHistory(['a', 'b', 'c', 'd', 'e']);
 expect(small.lineCount, 5);

 // Push one more line via append
 small.appendNewContent(['x']);
 small.appendNewContent(['y']); // 'x' scrolls off
 expect(small.lineCount, 5); // still capped at 5
 // oldest line 'a' should be evicted
 expect(small.getRange(0, 1).first, isNot('a'));
 });

 test('getRange clamps to available range', () {
 buffer.seedHistory(['a', 'b']);
 expect(buffer.getRange(0, 100), ['a', 'b']);
 expect(buffer.getRange(5, 10), isEmpty);
 });

 test('clear resets all state', () {
 buffer.seedHistory(['a', 'b']);
 buffer.clear();
 expect(buffer.lineCount, 0);
 });

 test('getAllLines returns full scrollback + visible', () {
 buffer.seedHistory(['old1', 'old2']);
 buffer.appendNewContent(['v1', 'v2', 'v3']);
 final all = buffer.getAllLines(['v1', 'v2', 'v3']);
 expect(all, ['old1', 'old2', 'v1', 'v2', 'v3']);
 });
 });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/terminal/scrollback_buffer_test.dart`
Expected: FAIL (file not found)

- [ ] **Step 3: Implement ScrollbackBuffer**

```dart
// lib/services/terminal/scrollback_buffer.dart
import 'dart:collection';

/// Client-side scrollback ring buffer for terminal history.
///
/// Accumulates lines that scroll off the top of the visible pane,
/// allowing instant local scrollback without SSH round-trips.
class ScrollbackBuffer {
 final int maxLines;
 final Queue<String> _lines = Queue<String>();

 /// Last visible content (for detecting scrolled-off lines)
 List<String> _previousVisible = [];

 ScrollbackBuffer({this.maxLines = 10000});

 /// Number of lines in the scrollback buffer.
 int get lineCount => _lines.length;

 /// Detect lines that scrolled off the top and add them to the buffer.
 ///
 /// Compares [currentVisible] with the previous visible content to find
 /// lines that are no longer visible (scrolled off the top).
 void appendNewContent(List<String> currentVisible) {
 if (_previousVisible.isEmpty) {
 _previousVisible = List.of(currentVisible);
 return;
 }

 // Find where the previous content starts in the new content.
 // The overlap tells us how many lines scrolled off.
 final scrolledOff = _findScrolledOffLines(_previousVisible, currentVisible);

 for (final line in scrolledOff) {
 _lines.addLast(line);
 _evictIfNeeded();
 }

 _previousVisible = List.of(currentVisible);
 }

 /// Find lines from [previous] that are no longer in [current]
 /// (they scrolled off the top).
 List<String> _findScrolledOffLines(
 List<String> previous, List<String> current) {
 if (previous.isEmpty || current.isEmpty) return previous;

 // Find the first line of current in previous to determine overlap
 final firstCurrentLine = current.first;
 int overlapStart = -1;

 for (int i = 0; i < previous.length; i++) {
 if (previous[i] == firstCurrentLine) {
 // Verify this is a real match by checking subsequent lines
 bool isMatch = true;
 final overlapLen = previous.length - i;
 final checkLen =
 overlapLen < current.length ? overlapLen : current.length;
 for (int j = 1; j < checkLen; j++) {
 if (previous[i + j] != current[j]) {
 isMatch = false;
 break;
 }
 }
 if (isMatch) {
 overlapStart = i;
 break;
 }
 }
 }

 if (overlapStart <= 0) {
 // No overlap found or nothing scrolled off
 if (overlapStart == -1) {
 // Complete content change — all previous lines scrolled off
 return List.of(previous);
 }
 return [];
 }

 // Lines 0..overlapStart-1 scrolled off
 return previous.sublist(0, overlapStart);
 }

 /// Bulk load existing scrollback history (e.g., on first scroll-up).
 void seedHistory(List<String> lines) {
 _lines.clear();
 for (final line in lines) {
 _lines.addLast(line);
 }
 // Trim to max if seeded with more
 while (_lines.length > maxLines) {
 _lines.removeFirst();
 }
 }

 /// Get a range of scrollback lines.
 ///
 /// [start] and [end] are 0-indexed from the oldest line.
 /// Returns empty list if range is out of bounds.
 List<String> getRange(int start, int end) {
 if (start >= _lines.length) return [];
 final clampedEnd = end > _lines.length ? _lines.length : end;
 final clampedStart = start < 0 ? 0 : start;
 if (clampedStart >= clampedEnd) return [];
 return _lines.toList().sublist(clampedStart, clampedEnd);
 }

 /// Get all scrollback lines concatenated with current visible lines.
 List<String> getAllLines(List<String> currentVisible) {
 return [..._lines, ...currentVisible];
 }

 /// Clear all scrollback (e.g., on pane switch).
 void clear() {
 _lines.clear();
 _previousVisible = [];
 }

 void _evictIfNeeded() {
 while (_lines.length > maxLines) {
 _lines.removeFirst();
 }
 }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/terminal/scrollback_buffer_test.dart`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/terminal/scrollback_buffer.dart test/services/terminal/scrollback_buffer_test.dart
git commit -m "feat(terminal): add client-side scrollback ring buffer"
```

---

### Task 1: Reduce capture-pane to visible area only

**Goal:** Change the polling loop to capture only the visible pane area instead of 1000 lines, reducing data transfer by ~97%.

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart:824-825` (capture-pane command)
- Modify: `lib/screens/terminal/terminal_screen.dart:793-933` (integrate scrollback buffer)

**Acceptance Criteria:**
- [ ] `capture-pane` uses no `-S` flag (defaults to visible area only, equivalent to `capturePaneVisible`)
- [ ] ScrollbackBuffer is instantiated per-pane and fed each poll's visible lines
- [ ] Buffer is cleared on pane switch
- [ ] On manual scroll-up past the visible area, a one-time `capture-pane -S -1000` seeds the scrollback buffer

**Verify:** Connect to a tmux session running Claude Code, observe latency indicator drops significantly (target: <500ms)

**Steps:**

- [ ] **Step 1: Add ScrollbackBuffer field to _TerminalScreenState**

In `lib/screens/terminal/terminal_screen.dart`, add import and field:

```dart
// Add import near the top (after other service imports)
import '../../services/terminal/scrollback_buffer.dart';
```

Add field in `_TerminalScreenState` after the `_inputQueue` field (~line 167):

```dart
 // （history）
 final _scrollbackBuffer = ScrollbackBuffer();
```

- [ ] **Step 2: Change capture-pane command to visible area only**

Replace the combined command construction at line 824-827:

```dart
 // Before:
 // '${_resolveMuxCmd(TmuxCommands.capturePane(target, escapeSequences: true, startLine: -1000))}; '

 // After: capture visible area only (no -S flag)
 final combinedCommand =
 '${_resolveMuxCmd(TmuxCommands.capturePaneVisible(target))}; '
 '${_resolveMuxCmd(TmuxCommands.getCursorPosition(target))}; '
 '${_resolveMuxCmd(TmuxCommands.getPaneMode(target))}';
```

- [ ] **Step 3: Feed scrollback buffer on each poll**

After `processedOutput` is computed (~line 843), add:

```dart
 // Feed scrollback buffer with visible lines
 final visibleLines = processedOutput.split('\n');
 _scrollbackBuffer.appendNewContent(visibleLines);
```

- [ ] **Step 4: Clear scrollback on pane switch**

Find the pane-switch method (where `currentTarget` changes) and add `_scrollbackBuffer.clear()`. This is typically in `_selectPane` or similar navigation methods.

- [ ] **Step 5: Build and test on device**

Run: `flutter run -d android`
Verify: Latency indicator shows <500ms on Claude Code session. Scrolling down still works. Content displays correctly.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "perf(terminal): capture visible area only instead of 1000 lines per poll"
```

---

### Task 2: Use persistent shell for keystrokes

**Goal:** Switch keystroke sending from `exec()` (opens new SSH channel per key) to `execPersistent()` (reuses existing channel), eliminating ~100-200ms per keystroke.

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart:1289` (sendKeyData method)

**Acceptance Criteria:**
- [ ] `_sendKeyData` uses `execPersistent` instead of `exec`
- [ ] Keystroke response time is noticeably faster

**Verify:** Type characters in terminal, observe they appear with less delay

**Steps:**

- [ ] **Step 1: Change exec to execPersistent in _sendKeyData**

In `lib/screens/terminal/terminal_screen.dart` at line 1289:

```dart
 // Before:
 // await sshClient.exec(_resolveMuxCmd(TmuxCommands.sendKeys(target, data, literal: true)));

 // After: use persistent shell (no SSH channel open/close overhead)
 await sshClient.execPersistent(_resolveMuxCmd(TmuxCommands.sendKeys(target, data, literal: true)));
```

- [ ] **Step 2: Test on device**

Run: `flutter run -d android`
Verify: Typing in terminal feels more responsive. No errors in debug console.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "perf(terminal): use persistent shell for keystroke sending"
```

---

### Task 3: Add dedicated input shell to eliminate serialization

**Goal:** Add a second persistent shell dedicated to input (send-keys), so keystrokes never wait for a poll cycle to finish. The existing persistent shell continues handling polling.

**Files:**
- Modify: `lib/services/ssh/ssh_client.dart:131-140` (add second shell field)
- Modify: `lib/services/ssh/ssh_client.dart:360-370` (initialize input shell)
- Modify: `lib/services/ssh/ssh_client.dart` (add `execInput` method)
- Modify: `lib/screens/terminal/terminal_screen.dart:1289` (use `execInput`)

**Acceptance Criteria:**
- [ ] `SshClientService` has a `_inputShell` (second PersistentShell) initialized alongside `_persistentShell`
- [ ] `execInput(command)` method executes on the input shell
- [ ] Keystrokes use `execInput` so they never block on polling
- [ ] Input shell falls back to `exec()` if unavailable (same pattern as `execPersistent`)

**Verify:** Type while Claude Code is streaming output — keystrokes should not stall

**Steps:**

- [ ] **Step 1: Add _inputShell field to SshClientService**

In `lib/services/ssh/ssh_client.dart` after `_persistentShell` field (~line 131):

```dart
 /// input（pollingpossible）
 PersistentShell? _inputShell;
```

- [ ] **Step 2: Initialize _inputShell in startPersistentShell**

In the `startPersistentShell()` method (~line 360), after `_persistentShell` is started:

```dart
 _persistentShell = PersistentShell(_client!);
 await _persistentShell!.start();

 // input
 _inputShell = PersistentShell(_client!);
 await _inputShell!.start();
```

- [ ] **Step 3: Dispose _inputShell in disconnect and restartPersistentShell**

In `disconnect()` (~line 341):

```dart
 await _persistentShell?.dispose();
 _persistentShell = null;
 await _inputShell?.dispose();
 _inputShell = null;
```

In `restartPersistentShell()` (~line 378):

```dart
 await _persistentShell?.dispose();
 _persistentShell = PersistentShell(_client!);
 await _persistentShell!.start();

 await _inputShell?.dispose();
 _inputShell = PersistentShell(_client!);
 await _inputShell!.start();
```

- [ ] **Step 4: Add execInput method**

After `execPersistent()` method (~line 741):

```dart
 /// inputvia（pollingpossible）
 ///
 /// send-keysinput。pollinguse
 /// independent、polling。
 Future<String> execInput(String command, {Duration? timeout}) async {
 if (!isConnected || _client == null) {
 throw SshConnectionError('Not connected');
 }

 final resolvedCommand = _resolveTmuxCommand(command);

 if (_inputShell == null || !_inputShell!.isStarted) {
 // : inputexecPersistentuse
 return execPersistent(resolvedCommand, timeout: timeout);
 }

 try {
 return await _inputShell!.exec(resolvedCommand, timeout: timeout);
 } on PersistentShellError catch (e) {
 if (e.message.contains('closed') || e.message.contains('disposed')) {
 try {
 await _inputShell!.restart();
 return await _inputShell!.exec(resolvedCommand, timeout: timeout);
 } catch (_) {
 return execPersistent(resolvedCommand, timeout: timeout);
 }
 }
 return execPersistent(resolvedCommand, timeout: timeout);
 }
 }
```

- [ ] **Step 5: Use execInput in _sendKeyData**

In `lib/screens/terminal/terminal_screen.dart` at line 1289:

```dart
 // Use dedicated input shell (no serialization with polling)
 await sshClient.execInput(_resolveMuxCmd(TmuxCommands.sendKeys(target, data, literal: true)));
```

- [ ] **Step 6: Test on device**

Run: `flutter run -d android`
Verify: Type while Claude Code is actively streaming output. Keystrokes should not stall or queue up.

- [ ] **Step 7: Commit**

```bash
git add lib/services/ssh/ssh_client.dart lib/screens/terminal/terminal_screen.dart
git commit -m "perf(ssh): add dedicated input shell for non-blocking keystroke sending"
```

---

### Task 4: Immediate poll after keystroke + fire-and-forget send-keys

**Goal:** After sending a keystroke, trigger an immediate poll instead of waiting for the next scheduled interval. Make send-keys fire-and-forget since its output is unused.

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart:770-775` (`_boostPolling` method)
- Modify: `lib/screens/terminal/terminal_screen.dart:1287-1290` (`_sendKeyData` method)

**Acceptance Criteria:**
- [ ] `_boostPolling()` triggers an immediate `_pollPaneContent()` instead of just resetting the interval
- [ ] `_sendKeyData` does not `await` the send-keys command (fire-and-forget)
- [ ] Error handling still catches and logs persistent shell errors

**Verify:** Type a character → it appears on screen within one poll cycle (50-100ms) instead of waiting up to current interval

**Steps:**

- [ ] **Step 1: Make _boostPolling trigger immediate poll**

Replace `_boostPolling()` at line 770-775:

```dart
 /// inputpolling（improvement）
 void _boostPolling() {
 _currentPollingInterval = _minPollingInterval;
 _pollTimer?.cancel();
 // polling
 _pollPaneContent().then((_) => _scheduleNextPoll());
 }
```

- [ ] **Step 2: Make send-keys fire-and-forget**

Replace `_sendKeyData` at lines 1287-1294:

```dart
 try {
 // Fire-and-forget: send-keysresultawait
 // inputuse（pollingpossible）
 sshClient.execInput(_resolveMuxCmd(TmuxCommands.sendKeys(target, data, literal: true))).catchError((_) {
 // error
 });
 _boostPolling();
 } catch (_) {
 // error
 }
```

- [ ] **Step 3: Test on device**

Run: `flutter run -d android`
Verify: Character appears almost immediately after typing. No errors in console.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "perf(terminal): immediate poll after keystroke, fire-and-forget send-keys"
```

---

### Task 5: Add on-demand scrollback fetch for scroll-up

**Goal:** When the user scrolls up past the visible area, do a one-time bulk `capture-pane -S -1000` to seed the scrollback buffer with history.

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart` (scroll listener, scrollback fetch)
- Modify: `lib/screens/terminal/widgets/ansi_text_view.dart` (notify parent when scrolled to top)

**Acceptance Criteria:**
- [ ] When user scrolls to the top of the current content, a one-time history fetch is triggered
- [ ] Fetched history is seeded into `_scrollbackBuffer`
- [ ] The full content (scrollback + visible) is passed to `AnsiTextView` for display
- [ ] History fetch only happens once per scroll-to-top (not repeatedly)

**Verify:** Scroll up in a Claude Code session → history loads, further scroll shows older output

**Steps:**

- [ ] **Step 1: Add scroll-to-top detection**

Add a method to detect when scroll position reaches the top. In `_TerminalScreenState`:

```dart
 bool _isLoadingScrollback = false;
 bool _scrollbackSeeded = false;

 /// historyretrieve
 Future<void> _onScrollTopReached() async {
 if (_isLoadingScrollback || _scrollbackSeeded) return;
 _isLoadingScrollback = true;

 try {
 final sshClient = ref.read(sshProvider.notifier).client;
 final target = ref.read(tmuxProvider.notifier).currentTarget;
 if (sshClient == null || target == null) return;

 // historyretrieve
 final historyOutput = await sshClient.execPersistent(
 _resolveMuxCmd(TmuxCommands.capturePane(target, escapeSequences: true, startLine: -1000)),
 timeout: const Duration(seconds: 3),
 );

 if (!mounted || _isDisposed) return;

 final historyLines = historyOutput.split('\n');
 // current
 final paneHeight = _viewNotifier.value.paneHeight;
 if (historyLines.length > paneHeight) {
 final scrollbackLines = historyLines.sublist(0, historyLines.length - paneHeight);
 _scrollbackBuffer.seedHistory(scrollbackLines);
 _scrollbackSeeded = true;
 }
 } catch (_) {
 // errorpossible_scrollbackSeededfalse
 } finally {
 _isLoadingScrollback = false;
 }
 }
```

- [ ] **Step 2: Wire scroll listener to _terminalScrollController**

In `initState` or the connection setup, add:

```dart
 _terminalScrollController.addListener(() {
 if (_terminalScrollController.hasClients &&
 _terminalScrollController.offset <= 0) {
 _onScrollTopReached();
 }
 });
```

- [ ] **Step 3: Reset scrollback state on pane switch**

In the pane-switch method, add:

```dart
 _scrollbackBuffer.clear();
 _scrollbackSeeded = false;
```

- [ ] **Step 4: Test on device**

Run: `flutter run -d android`
Verify: Open a long Claude Code session. Scroll up — history loads. Scroll down returns to live view.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "feat(terminal): on-demand scrollback fetch when scrolling to top"
```

---

### Task 6: Verify latency improvement with user

**Goal:** Get user confirmation that latency has improved from 2000+ms to a usable level.

**User Verification Required:**
Before marking this task complete, you MUST call AskUserQuestion:
```yaml
AskUserQuestion:
 question: "What latency do you see now when connected to a Claude Code session? (baseline was 2000+ms / ~2-3s refresh)"
 header: "Verification"
 options:
 - label: "Under 200ms"
 description: "Major improvement — target achieved"
 - label: "200-500ms"
 description: "Good improvement — may need further tuning"
 - label: "Still over 500ms"
 description: "Needs more investigation and rework"
```

**If the user selects "Still over 500ms":** The task is NOT complete. Investigate further bottlenecks (ANSI parsing overhead, network conditions, persistent shell startup) and re-verify.

**Files:** (none — verification only)

**Acceptance Criteria:**
- [ ] User confirms latency is under 500ms on real device

**Verify:** User-reported latency measurement

```json:metadata
{"files": [], "verifyCommand": "", "acceptanceCriteria": ["user confirms latency reduction"], "requiresUserVerification": true, "userVerificationPrompt": "What latency do you see now when connected to a Claude Code session? (baseline was 2000+ms / ~2-3s refresh)"}
```
