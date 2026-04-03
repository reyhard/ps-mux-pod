import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/terminal/scrollback_buffer.dart';

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
      buffer.appendNewContent(['line1', 'line2', 'line3']);
      expect(buffer.lineCount, 0);
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
      small.appendNewContent(['x']);
      small.appendNewContent(['y']);
      expect(small.lineCount, 5);
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
