import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/screens/terminal/terminal_input_lock.dart';
import 'package:flutter_muxpod/widgets/special_keys_bar.dart';
import 'package:xterm/xterm.dart';

class _TerminalInputHarness extends StatefulWidget {
  final List<String> output;

  const _TerminalInputHarness({required this.output});

  @override
  State<_TerminalInputHarness> createState() => _TerminalInputHarnessState();
}

class _TerminalInputHarnessState extends State<_TerminalInputHarness> {
  late final Terminal _terminal;
  late final FocusNode _terminalFocusNode;
  bool _directInputEnabled = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(onOutput: widget.output.add);
    _terminalFocusNode = FocusNode(skipTraversal: true);
  }

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _blockTerminalInput(FocusNode node, KeyEvent event) {
    return blockTerminalTypingButAllowSelectionShortcuts(node, event);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: TerminalView(
                _terminal,
                focusNode: _terminalFocusNode,
                autofocus: false,
                readOnly: true,
                onKeyEvent: _blockTerminalInput,
              ),
            ),
            SpecialKeysBar(
              onKeyPressed: widget.output.add,
              onSpecialKeyPressed: widget.output.add,
              directInputEnabled: _directInputEnabled,
              onDirectInputToggle: () {
                setState(() {
                  _directInputEnabled = !_directInputEnabled;
                });
              },
              hapticFeedback: false,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Terminal input lock', () {
    testWidgets('allows selection shortcuts but still blocks hardware typing', (
      tester,
    ) async {
      final output = <String>[];
      final controller = TerminalController();
      final focusNode = FocusNode(skipTraversal: true);
      final terminal = Terminal(onOutput: output.add);
      String? clipboardText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboardText =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return <String, Object?>{'text': clipboardText};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      terminal.write('hello from the terminal');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: controller,
              focusNode: focusNode,
              autofocus: false,
              readOnly: true,
              onKeyEvent: blockTerminalTypingButAllowSelectionShortcuts,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pump(const Duration(milliseconds: 350));

      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(output, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.selection, isNotNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(clipboardText, contains('hello from the terminal'));

      controller.dispose();
      focusNode.dispose();
    });
  });

  group('SpecialKeysBar raw input', () {
    testWidgets(
      'applies sticky CTRL to the next raw typed letter and resets it',
      (tester) async {
        final literalKeys = <String>[];
        final specialKeys = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SpecialKeysBar(
                onKeyPressed: literalKeys.add,
                onSpecialKeyPressed: specialKeys.add,
                hapticFeedback: false,
              ),
            ),
          ),
        );

        await tester.tap(find.text('RAW'));
        await tester.pump();

        await tester.tap(find.text('CTRL'));
        await tester.pump();

        final rawInput = find.byType(TextField);
        expect(rawInput, findsOneWidget);

        await tester.enterText(rawInput, 'o');
        await tester.pump();

        expect(literalKeys, isEmpty);
        expect(specialKeys, <String>[String.fromCharCode(0x0F)]);

        await tester.enterText(rawInput, 'o');
        await tester.pump();

        expect(literalKeys, <String>['o']);
        expect(specialKeys, <String>[String.fromCharCode(0x0F)]);
      },
    );
  });

  group('SpecialKeysBar live input', () {
    testWidgets('still sends typed text through the LIVE field', (
      tester,
    ) async {
      final output = <String>[];

      await tester.pumpWidget(_TerminalInputHarness(output: output));

      await tester.tap(find.byIcon(Icons.flash_off));
      await tester.pump();

      final liveInput = find.byType(TextField);
      expect(liveInput, findsOneWidget);

      await tester.enterText(liveInput, 'pwd');
      await tester.pump();

      expect(output, <String>['pwd']);
    });
  });

  group('SpecialKeysBar Claude Code shortcuts', () {
    testWidgets('shows icon shortcuts and sends the expected special keys', (
      tester,
    ) async {
      final literalKeys = <String>[];
      final specialKeys = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialKeysBar(
              onKeyPressed: literalKeys.add,
              onSpecialKeyPressed: specialKeys.add,
              hapticFeedback: false,
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsNothing);
      expect(find.text('End'), findsNothing);
      expect(find.text('Del'), findsNothing);
      expect(find.text('Ins'), findsNothing);

      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.route_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop_circle_outlined));
      await tester.pump();

      expect(literalKeys, isEmpty);
      expect(specialKeys, <String>[
        Vt100Keys.ctrl('o'),
        Vt100Keys.backTab,
        Vt100Keys.ctrl('c'),
      ]);
    });

    testWidgets('toggles quick actions and sends literal option keys', (
      tester,
    ) async {
      final literalKeys = <String>[];
      final specialKeys = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialKeysBar(
              onKeyPressed: literalKeys.add,
              onSpecialKeyPressed: specialKeys.add,
              hapticFeedback: false,
            ),
          ),
        ),
      );

      expect(find.text('Y'), findsNothing);
      expect(find.text('N'), findsNothing);

      await tester.tap(find.byIcon(Icons.keyboard_command_key));
      await tester.pumpAndSettle();

      expect(find.text('Y'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('Y'));
      await tester.pump();
      await tester.tap(find.text('N'));
      await tester.pump();

      expect(literalKeys, <String>['1', 'y', 'n']);
      expect(specialKeys, isEmpty);

      await tester.tap(find.byIcon(Icons.keyboard_command_key));
      await tester.pumpAndSettle();

      expect(find.text('Y'), findsNothing);
      expect(find.text('N'), findsNothing);
    });
  });

  group('SpecialKeysBar Codex shortcuts', () {
    testWidgets('shows Codex profile shortcuts and sends expected keys', (
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

      expect(find.text('Lower'), findsNothing);
      expect(find.text('Raise'), findsNothing);

      await tester.tap(find.byIcon(Icons.speed_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Lower'), findsOneWidget);
      expect(find.text('Raise'), findsOneWidget);

      await tester.tap(find.text('Lower'));
      await tester.pump();
      await tester.tap(find.text('Raise'));
      await tester.pump();

      expect(literalKeys, isEmpty);
      expect(specialKeys, <String>[
        Vt100Keys.backTab,
        Vt100Keys.ctrl('t'),
        Vt100Keys.alt(','),
        Vt100Keys.alt('.'),
      ]);
    });
  });
}
