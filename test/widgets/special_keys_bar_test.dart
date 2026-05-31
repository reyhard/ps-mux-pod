import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/widgets/special_keys_bar.dart';

void main() {
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

      expect(literalKeys, <String>['1', 'Y', 'N']);
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
