import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
