import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
