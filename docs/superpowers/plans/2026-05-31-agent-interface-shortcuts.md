# Agent Interface Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-connection Claude Code/Codex interface setting that controls the terminal special keys shortcut profile.

**Architecture:** Store the selected interface on `Connection` as a stable string value, using a small shared enum helper so UI, persistence, terminal wiring, and shortcut widgets agree on values. Keep shortcut behavior inside `SpecialKeysBar`; `TerminalScreen` only resolves the active connection and passes the chosen profile.

**Tech Stack:** Flutter, Dart, Riverpod, SharedPreferences, flutter_test.

---

## File Structure

- Create `lib/models/agent_interface.dart`
  - Owns `AgentInterface`, storage values, display labels, and safe parsing.
- Modify `lib/providers/connection_provider.dart`
  - Adds `agentInterface` to `Connection`, JSON persistence, copying, and migration defaults.
- Modify `lib/screens/connections/connection_form_screen.dart`
  - Adds the Agent Interface field and persists the selected value.
- Modify `lib/widgets/special_keys_bar.dart`
  - Adds profile-aware navigation rows and the Codex effort row.
- Modify `lib/screens/terminal/terminal_screen.dart`
  - Watches the saved connection and passes its interface to `SpecialKeysBar`.
- Create `test/models/agent_interface_test.dart`
  - Covers parsing, fallback, labels, and storage values.
- Create `test/providers/connection_provider_test.dart`
  - Covers connection JSON migration and persistence.
- Create `test/screens/connection_form_screen_test.dart`
  - Covers form display, loading an existing Codex connection, and saving changes.
- Modify `test/widgets/special_keys_bar_test.dart`
  - Keeps Claude behavior covered and adds Codex shortcut behavior.

## Command Rules

This repository's `AGENTS.md` requires Flutter commands to run with escalated permissions immediately in this environment. When executing this plan, run every `flutter test`, `flutter analyze`, `flutter run`, or `flutter build` command with escalation, not sandbox-first.

The working tree may already contain unrelated user changes. Do not revert unrelated files.

---

### Task 1: Shared Agent Interface Type

**Files:**
- Create: `lib/models/agent_interface.dart`
- Create: `test/models/agent_interface_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models/agent_interface_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';

void main() {
  group('AgentInterface', () {
    test('parses known storage values', () {
      expect(agentInterfaceFromStorage('claude'), AgentInterface.claude);
      expect(agentInterfaceFromStorage('codex'), AgentInterface.codex);
    });

    test('falls back to Claude for missing or unknown values', () {
      expect(agentInterfaceFromStorage(null), AgentInterface.claude);
      expect(agentInterfaceFromStorage(''), AgentInterface.claude);
      expect(agentInterfaceFromStorage('other'), AgentInterface.claude);
    });

    test('exposes stable storage values and labels', () {
      expect(AgentInterface.claude.storageValue, 'claude');
      expect(AgentInterface.codex.storageValue, 'codex');
      expect(AgentInterface.claude.displayLabel, 'Claude Code');
      expect(AgentInterface.codex.displayLabel, 'Codex');
    });
  });
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run: `flutter test test/models/agent_interface_test.dart`

Expected: FAIL because `lib/models/agent_interface.dart` does not exist.

- [ ] **Step 3: Create the shared model**

Create `lib/models/agent_interface.dart`:

```dart
enum AgentInterface {
  claude,
  codex,
}

extension AgentInterfaceLabels on AgentInterface {
  String get storageValue {
    switch (this) {
      case AgentInterface.claude:
        return 'claude';
      case AgentInterface.codex:
        return 'codex';
    }
  }

  String get displayLabel {
    switch (this) {
      case AgentInterface.claude:
        return 'Claude Code';
      case AgentInterface.codex:
        return 'Codex';
    }
  }
}

AgentInterface agentInterfaceFromStorage(String? value) {
  switch (value) {
    case 'codex':
      return AgentInterface.codex;
    case 'claude':
    default:
      return AgentInterface.claude;
  }
}
```

- [ ] **Step 4: Run the model test to verify it passes**

Run: `flutter test test/models/agent_interface_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/agent_interface.dart test/models/agent_interface_test.dart
git commit -m "feat: add agent interface model"
```

---

### Task 2: Connection Persistence

**Files:**
- Modify: `lib/providers/connection_provider.dart`
- Create: `test/providers/connection_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/providers/connection_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';

void main() {
  group('Connection agentInterface persistence', () {
    test('defaults missing agentInterface to Claude', () {
      final connection = Connection.fromJson({
        'id': 'conn-1',
        'name': 'Production',
        'host': 'example.com',
        'port': 22,
        'username': 'deploy',
        'authMethod': 'password',
        'createdAt': DateTime(2026, 5, 31).toIso8601String(),
      });

      expect(connection.agentInterface, AgentInterface.claude);
    });

    test('falls back to Claude for unknown agentInterface values', () {
      final connection = Connection.fromJson({
        'id': 'conn-1',
        'name': 'Production',
        'host': 'example.com',
        'port': 22,
        'username': 'deploy',
        'authMethod': 'password',
        'createdAt': DateTime(2026, 5, 31).toIso8601String(),
        'agentInterface': 'unsupported',
      });

      expect(connection.agentInterface, AgentInterface.claude);
    });

    test('persists Codex agentInterface to JSON', () {
      final connection = Connection(
        id: 'conn-1',
        name: 'Production',
        host: 'example.com',
        username: 'deploy',
        createdAt: DateTime(2026, 5, 31),
        agentInterface: AgentInterface.codex,
      );

      expect(connection.toJson()['agentInterface'], 'codex');
    });

    test('copyWith can update agentInterface', () {
      final connection = Connection(
        id: 'conn-1',
        name: 'Production',
        host: 'example.com',
        username: 'deploy',
        createdAt: DateTime(2026, 5, 31),
      );

      final updated = connection.copyWith(agentInterface: AgentInterface.codex);

      expect(connection.agentInterface, AgentInterface.claude);
      expect(updated.agentInterface, AgentInterface.codex);
    });
  });
}
```

- [ ] **Step 2: Run the new provider test to verify it fails**

Run: `flutter test test/providers/connection_provider_test.dart`

Expected: FAIL because `Connection.agentInterface` does not exist.

- [ ] **Step 3: Add the field to `Connection`**

Modify `lib/providers/connection_provider.dart`:

```dart
import '../models/agent_interface.dart';
```

Add the field near `nestedTmux`:

```dart
  /// Agent shortcut interface: Claude Code or Codex
  final AgentInterface agentInterface;
```

Add the constructor parameter:

```dart
    this.nestedTmux = false,
    this.agentInterface = AgentInterface.claude,
```

Add to `copyWith` parameters:

```dart
    AgentInterface? agentInterface,
```

Add to the returned `Connection`:

```dart
      agentInterface: agentInterface ?? this.agentInterface,
```

Add to `toJson`:

```dart
      'agentInterface': agentInterface.storageValue,
```

Add to `fromJson`:

```dart
      agentInterface: agentInterfaceFromStorage(json['agentInterface'] as String?),
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/providers/connection_provider_test.dart`

Expected: PASS.

- [ ] **Step 5: Run the model test to catch import regressions**

Run: `flutter test test/models/agent_interface_test.dart test/providers/connection_provider_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/connection_provider.dart test/providers/connection_provider_test.dart
git commit -m "feat: persist connection agent interface"
```

---

### Task 3: Connection Form Field

**Files:**
- Modify: `lib/screens/connections/connection_form_screen.dart`
- Create: `test/screens/connection_form_screen_test.dart`

- [ ] **Step 1: Write the failing form tests**

Create `test/screens/connection_form_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';
import 'package:flutter_muxpod/screens/connections/connection_form_screen.dart';

class _FakeConnectionsNotifier extends ConnectionsNotifier {
  _FakeConnectionsNotifier(this.initialConnections);

  final List<Connection> initialConnections;
  Connection? addedConnection;
  Connection? updatedConnection;

  @override
  ConnectionsState build() {
    return ConnectionsState(connections: initialConnections);
  }

  @override
  Connection? getById(String id) {
    for (final connection in state.connections) {
      if (connection.id == id) {
        return connection;
      }
    }
    return null;
  }

  @override
  Future<void> add(Connection connection) async {
    addedConnection = connection;
    state = state.copyWith(connections: [...state.connections, connection]);
  }

  @override
  Future<void> update(Connection connection) async {
    updatedConnection = connection;
    state = state.copyWith(
      connections: [
        for (final existing in state.connections)
          if (existing.id == connection.id) connection else existing,
      ],
    );
  }
}

void main() {
  Widget buildForm({
    required _FakeConnectionsNotifier notifier,
    String? connectionId,
  }) {
    return ProviderScope(
      overrides: [
        connectionsProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        home: ConnectionFormScreen(connectionId: connectionId),
      ),
    );
  }

  group('ConnectionFormScreen agent interface', () {
    testWidgets('shows Agent Interface with Claude default', (tester) async {
      final notifier = _FakeConnectionsNotifier([]);

      await tester.pumpWidget(buildForm(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('AGENT INTERFACE'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Codex'), findsNothing);
    });

    testWidgets('loads Codex for an existing connection', (tester) async {
      final notifier = _FakeConnectionsNotifier([
        Connection(
          id: 'conn-1',
          name: 'Production',
          host: 'example.com',
          username: 'deploy',
          createdAt: DateTime(2026, 5, 31),
          agentInterface: AgentInterface.codex,
        ),
      ]);

      await tester.pumpWidget(
        buildForm(notifier: notifier, connectionId: 'conn-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Connection'), findsOneWidget);
      expect(find.text('AGENT INTERFACE'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
    });

    testWidgets('saves changed agent interface on edit', (tester) async {
      final notifier = _FakeConnectionsNotifier([
        Connection(
          id: 'conn-1',
          name: 'Production',
          host: 'example.com',
          username: 'deploy',
          createdAt: DateTime(2026, 5, 31),
        ),
      ]);

      await tester.pumpWidget(
        buildForm(notifier: notifier, connectionId: 'conn-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claude Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.updatedConnection, isNotNull);
      expect(notifier.updatedConnection!.agentInterface, AgentInterface.codex);
    });
  });
}
```

- [ ] **Step 2: Run the form test to verify it fails**

Run: `flutter test test/screens/connection_form_screen_test.dart`

Expected: FAIL because the form has no Agent Interface field.

- [ ] **Step 3: Add imports and state**

Modify `lib/screens/connections/connection_form_screen.dart`:

```dart
import '../../models/agent_interface.dart';
```

Add state near `_nestedTmux`:

```dart
  AgentInterface _agentInterface = AgentInterface.claude;
```

In `_loadExistingConnection`, add:

```dart
      _agentInterface = connection.agentInterface;
```

- [ ] **Step 4: Render the dropdown**

In `_buildServerSection`, add this block after `_buildTransportDropdown()` and before the WSL conditional:

```dart
              const SizedBox(height: 16),
              _buildFieldLabel('AGENT INTERFACE'),
              const SizedBox(height: 8),
              _buildAgentInterfaceDropdown(),
```

Add this helper near `_buildTransportDropdown()`:

```dart
  Widget _buildAgentInterfaceDropdown() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DesignColors.textMuted : DesignColors.textMutedLight;
    final inputColor = isDark ? DesignColors.inputDark : DesignColors.inputLight;
    return DropdownButtonFormField<AgentInterface>(
      initialValue: _agentInterface,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.smart_toy_outlined, color: mutedColor, size: 20),
        filled: true,
        fillColor: inputColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: colorScheme.surface,
      style: GoogleFonts.spaceGrotesk(fontSize: 14, color: colorScheme.onSurface),
      items: AgentInterface.values
          .map(
            (interface) => DropdownMenuItem<AgentInterface>(
              value: interface,
              child: Text(interface.displayLabel),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _agentInterface = value);
        }
      },
    );
  }
```

- [ ] **Step 5: Persist the selected value**

In `_save`, add the constructor argument:

```dart
        agentInterface: _agentInterface,
```

- [ ] **Step 6: Run the form test**

Run: `flutter test test/screens/connection_form_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Run model, provider, and form tests together**

Run: `flutter test test/models/agent_interface_test.dart test/providers/connection_provider_test.dart test/screens/connection_form_screen_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/connections/connection_form_screen.dart test/screens/connection_form_screen_test.dart
git commit -m "feat: add connection agent interface setting"
```

---

### Task 4: SpecialKeysBar Shortcut Profiles

**Files:**
- Modify: `lib/widgets/special_keys_bar.dart`
- Modify: `test/widgets/special_keys_bar_test.dart`

- [ ] **Step 1: Write the failing Codex shortcut test**

Append this test inside the `SpecialKeysBar Claude Code shortcuts` group or create a new group named `SpecialKeysBar Codex shortcuts` in `test/widgets/special_keys_bar_test.dart`:

```dart
    testWidgets('Codex profile sends plan transcript and effort shortcuts', (
      tester,
    ) async {
      final literalKeys = <String>[];
      final specialKeys = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialKeysBar(
              agentInterface: AgentInterface.codex,
              onKeyPressed: literalKeys.add,
              onSpecialKeyPressed: specialKeys.add,
              hapticFeedback: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.assignment_turned_in_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.article_outlined));
      await tester.pump();

      expect(literalKeys, isEmpty);
      expect(specialKeys, <String>[
        Vt100Keys.backTab,
        Vt100Keys.ctrl('t'),
      ]);

      await tester.tap(find.byIcon(Icons.speed_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Lower'), findsOneWidget);
      expect(find.text('Raise'), findsOneWidget);

      await tester.tap(find.text('Lower'));
      await tester.pump();
      await tester.tap(find.text('Raise'));
      await tester.pump();

      expect(specialKeys, <String>[
        Vt100Keys.backTab,
        Vt100Keys.ctrl('t'),
        Vt100Keys.alt(','),
        Vt100Keys.alt('.'),
      ]);
    });
```

Add the import at the top of `test/widgets/special_keys_bar_test.dart`:

```dart
import 'package:flutter_muxpod/models/agent_interface.dart';
```

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/widgets/special_keys_bar_test.dart`

Expected: FAIL because `SpecialKeysBar.agentInterface` and the Codex buttons do not exist.

- [ ] **Step 3: Import the shared type and add widget state**

Modify `lib/widgets/special_keys_bar.dart`:

```dart
import '../models/agent_interface.dart';
```

Add the widget property near `directInputEnabled`:

```dart
  /// Shortcut profile used by the navigation row
  final AgentInterface agentInterface;
```

Add the constructor default:

```dart
    this.agentInterface = AgentInterface.claude,
```

Add a second row toggle state near `_quickActionsOpen`:

```dart
  bool _effortActionsOpen = false;
```

- [ ] **Step 4: Update the animated rows**

Replace the single `AnimatedSwitcher` before `_buildNavigationKeysRow()` with:

```dart
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
              child: _effortActionsOpen
                  ? _buildEffortActionsRow()
                  : const SizedBox.shrink(
                      key: ValueKey('effort-actions-closed'),
                    ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: child,
              ),
              child: _quickActionsOpen
                  ? _buildQuickActionsRow()
                  : const SizedBox.shrink(
                      key: ValueKey('quick-actions-closed'),
                    ),
            ),
```

- [ ] **Step 5: Make the navigation row profile-aware**

Replace `_buildNavigationKeysRow()` with:

```dart
  /// Navigation keys row (PgUp, PgDn, agent shortcuts, quick actions toggle)
  Widget _buildNavigationKeysRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          _buildSpecialKeyButton('PgUp', Vt100Keys.pageUp),
          _buildSpecialKeyButton('PgDn', Vt100Keys.pageDown),
          ..._buildAgentShortcutButtons(),
          _buildQuickActionsToggle(),
        ],
      ),
    );
  }

  List<Widget> _buildAgentShortcutButtons() {
    switch (widget.agentInterface) {
      case AgentInterface.claude:
        return [
          _buildIconKeyButton(
            icon: Icons.description_outlined,
            vt100Key: Vt100Keys.ctrl('o'),
          ),
          _buildIconKeyButton(
            icon: Icons.route_outlined,
            vt100Key: Vt100Keys.backTab,
          ),
          _buildIconKeyButton(
            icon: Icons.stop_circle_outlined,
            vt100Key: Vt100Keys.ctrl('c'),
          ),
        ];
      case AgentInterface.codex:
        return [
          _buildIconKeyButton(
            icon: Icons.assignment_turned_in_outlined,
            vt100Key: Vt100Keys.backTab,
          ),
          _buildEffortActionsToggle(),
          _buildIconKeyButton(
            icon: Icons.article_outlined,
            vt100Key: Vt100Keys.ctrl('t'),
          ),
        ];
    }
  }
```

- [ ] **Step 6: Add the effort row and toggle**

Add near `_buildQuickActionsRow()`:

```dart
  Widget _buildEffortActionsRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('effort-actions-open'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          _buildQuickActionButton('Lower', Vt100Keys.alt(','), sendAsSpecial: true),
          _buildQuickActionButton('Raise', Vt100Keys.alt('.'), sendAsSpecial: true),
        ],
      ),
    );
  }
```

Replace `_buildQuickActionButton` with:

```dart
  Widget _buildQuickActionButton(
    String label,
    String key, {
    bool sendAsSpecial = false,
  }) {
    if (sendAsSpecial) {
      return _buildSpecialKeyButton(label, key);
    }
    return _buildLiteralKeyButton(label, key, ignoreModifiers: true);
  }
```

Add near `_buildQuickActionsToggle()`:

```dart
  Widget _buildEffortActionsToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () {
          setState(() {
            _effortActionsOpen = !_effortActionsOpen;
            if (_effortActionsOpen) {
              _quickActionsOpen = false;
            }
          });
        },
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _effortActionsOpen
                ? DesignColors.warning.withValues(alpha: 0.3)
                : (isDark
                      ? DesignColors.keyBackground
                      : DesignColors.keyBackgroundLight),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(
                color: _effortActionsOpen
                    ? DesignColors.warning.withValues(alpha: 0.5)
                    : (isDark ? Colors.black : Colors.grey.shade400),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.speed_outlined,
              size: 16,
              color: _effortActionsOpen
                  ? DesignColors.warning
                  : colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 7: Prevent both expandable rows from staying open**

In `_buildQuickActionsToggle`, update the `onTap` body:

```dart
        onTap: () {
          setState(() {
            _quickActionsOpen = !_quickActionsOpen;
            if (_quickActionsOpen) {
              _effortActionsOpen = false;
            }
          });
        },
```

In `didUpdateWidget`, add:

```dart
    if (widget.agentInterface != oldWidget.agentInterface) {
      _quickActionsOpen = false;
      _effortActionsOpen = false;
    }
```

- [ ] **Step 8: Run SpecialKeysBar tests**

Run: `flutter test test/widgets/special_keys_bar_test.dart`

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/special_keys_bar.dart test/widgets/special_keys_bar_test.dart
git commit -m "feat: add Codex shortcut profile"
```

---

### Task 5: Terminal Wiring

**Files:**
- Modify: `lib/screens/terminal/terminal_screen.dart`

- [ ] **Step 1: Locate the `SpecialKeysBar` build block**

Find the existing `SpecialKeysBar(` block near the bottom of `lib/screens/terminal/terminal_screen.dart`.

- [ ] **Step 2: Resolve the active connection while building**

Inside the nearest `build` method scope, before returning the widget tree or before the `SpecialKeysBar` block, add:

```dart
    final connectionsState = ref.watch(connectionsProvider);
    Connection? activeConnection;
    for (final connection in connectionsState.connections) {
      if (connection.id == widget.connectionId) {
        activeConnection = connection;
        break;
      }
    }
```

If the local scope already has a `connectionsState` variable, use a distinct name such as `terminalConnectionsState`.

- [ ] **Step 3: Pass the profile to `SpecialKeysBar`**

Update the `SpecialKeysBar` constructor call:

```dart
              SpecialKeysBar(
                agentInterface: activeConnection?.agentInterface ?? AgentInterface.claude,
                onKeyPressed: (String key) {
                  _writeToPty(key);
                },
                onSpecialKeyPressed: (String escapeSequence) {
                  _writeToPty(escapeSequence);
                },
                onInputTap: _showInputDialog,
                directInputEnabled: _directInputEnabled,
                onDirectInputToggle: () {
                  ref.read(settingsProvider.notifier).toggleDirectInput();
                },
              ),
```

Add the import if `terminal_screen.dart` does not already have it:

```dart
import '../../models/agent_interface.dart';
```

`Connection` is already available through `connection_provider.dart`; if the file does not currently import it, add:

```dart
import '../../providers/connection_provider.dart';
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/terminal/terminal_screen.dart
git commit -m "feat: wire terminal agent interface"
```

---

### Task 6: Full Verification

**Files:**
- No new source files.
- Verify all files touched by Tasks 1-5.

- [ ] **Step 1: Run focused tests**

Run:

```bash
flutter test test/models/agent_interface_test.dart test/providers/connection_provider_test.dart test/screens/connection_form_screen_test.dart test/widgets/special_keys_bar_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run all tests**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 3: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS.

- [ ] **Step 4: Manual verification on device or emulator**

Run the app and verify:

1. Open an existing connection in Edit Connection.
2. Confirm `AGENT INTERFACE` defaults to `Claude Code`.
3. Change it to `Codex` and save.
4. Open the terminal for that connection.
5. Confirm the navigation row shows Codex controls for Plan, Effort, and Transcript.
6. Tap Effort and confirm `Lower` and `Raise` appear.
7. Edit the connection back to `Claude Code`, reopen or return to terminal, and confirm the Claude shortcut icons return.

- [ ] **Step 5: Commit any verification-only fixes**

If Tasks 1-5 produced analyzer or test fixes, commit them:

```bash
git add lib test
git commit -m "fix: polish agent interface shortcuts"
```

Skip this commit if there are no additional fixes.

---

## Self-Review Notes

- Spec coverage: data model, connection form, shortcut profiles, terminal wiring, fallback behavior, and tests are covered by Tasks 1-6.
- Scope check: the plan is a single cohesive feature; it does not include customizable shortcuts, runtime switching, auto-detection, SSH, mux, or PTY changes.
- Type consistency: the plan uses `AgentInterface`, `agentInterface`, `storageValue`, `displayLabel`, and `agentInterfaceFromStorage` consistently across model, provider, form, terminal, and widget code.
