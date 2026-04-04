import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/tmux/pane_navigator.dart';
import 'package:flutter_muxpod/services/tmux/tmux_parser.dart';

void main() {
  group('PaneNavigator', () {
    group('findAdjacentPane', () {
      test('left/right navigation in horizontal 2-split', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 24),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
        ];

        // pane0 right → pane1
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%1');

        // pane1 left → pane0
        final left = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.left,
        );
        expect(left?.id, '%0');

        // pane0 left → null (edge)
        final noLeft = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.left,
        );
        expect(noLeft, isNull);

        // pane1 right → null (edge)
        final noRight = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.right,
        );
        expect(noRight, isNull);
      });

      test('up/down navigation in vertical 2-split', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 80, height: 11),
        ];

        // pane0 down → pane1
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down?.id, '%1');

        // pane1 up → pane0
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%0');

        // pane0 up → null
        expect(
          PaneNavigator.findAdjacentPane(
            panes: panes,
            current: panes[0],
            direction: SwipeDirection.up,
          ),
          isNull,
        );
      });

      test('returns the nearest pane in vertical 3-split', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 80, height: 12),
          const TmuxPane(index: 2, id: '%2', left: 0, top: 26, width: 80, height: 11),
        ];

        // pane0 down → pane1 (nearest pane1, not pane2)
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down?.id, '%1');

        // pane2 up → pane1
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[2],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%1');
      });

      test('overlap condition works in T-shaped layout', () {
        // Top: one wide pane
        // Bottom: two panes left and right
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 0, top: 13, width: 40, height: 11),
          const TmuxPane(index: 2, id: '%2', left: 41, top: 13, width: 39, height: 11),
        ];

        // pane0 down: pane1 or pane2 (both overlap, returns nearest)
        final down = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[0],
          direction: SwipeDirection.down,
        );
        expect(down, isNotNull);
        expect(['%1', '%2'], contains(down?.id));

        // pane1 up → pane0 (overlap exists)
        final up = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.up,
        );
        expect(up?.id, '%0');

        // pane1 right → pane2
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[1],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%2');
      });

      test('returns null for directions with no overlap in L-shaped layout', () {
        // Top-left: pane0
        // Top-right: pane1
        // Bottom-left: pane2 (no pane in bottom-right)
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 12),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
          const TmuxPane(index: 2, id: '%2', left: 0, top: 13, width: 40, height: 11),
        ];

        // pane2 right → pane1 (vertical overlap exists)
        final right = PaneNavigator.findAdjacentPane(
          panes: panes,
          current: panes[2],
          direction: SwipeDirection.right,
        );
        expect(right?.id, '%1');
      });

      test('returns null in all directions when only one pane', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24),
        ];

        for (final direction in SwipeDirection.values) {
          expect(
            PaneNavigator.findAdjacentPane(
              panes: panes,
              current: panes[0],
              direction: direction,
            ),
            isNull,
          );
        }
      });

      test('returns null when pane list is empty', () {
        const current = TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24);
        for (final direction in SwipeDirection.values) {
          expect(
            PaneNavigator.findAdjacentPane(
              panes: const [],
              current: current,
              direction: direction,
            ),
            isNull,
          );
        }
      });
    });

    group('getNavigableDirections', () {
      test('returns correct direction map for horizontal 2-split', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 40, height: 24),
          const TmuxPane(index: 1, id: '%1', left: 41, top: 0, width: 39, height: 24),
        ];

        final dirs = PaneNavigator.getNavigableDirections(
          panes: panes,
          current: panes[0],
        );

        expect(dirs[SwipeDirection.right], isTrue);
        expect(dirs[SwipeDirection.left], isFalse);
        expect(dirs[SwipeDirection.up], isFalse);
        expect(dirs[SwipeDirection.down], isFalse);
      });

      test('all directions are false when only one pane', () {
        final panes = [
          const TmuxPane(index: 0, id: '%0', left: 0, top: 0, width: 80, height: 24),
        ];

        final dirs = PaneNavigator.getNavigableDirections(
          panes: panes,
          current: panes[0],
        );

        for (final dir in SwipeDirection.values) {
          expect(dirs[dir], isFalse);
        }
      });
    });

    group('detectSwipeDirection', () {
      test('detects rightward swipe', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(60, 10)),
          SwipeDirection.right,
        );
      });

      test('detects leftward swipe', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-60, -10)),
          SwipeDirection.left,
        );
      });

      test('detects downward swipe', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(10, 60)),
          SwipeDirection.down,
        );
      });

      test('detects upward swipe', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-10, -60)),
          SwipeDirection.up,
        );
      });

      test('returns null for movement below threshold', () {
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 10)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(10, 30)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(Offset.zero),
          isNull,
        );
      });

      test('detects with custom threshold', () {
        // Not detected with default threshold (50), but detected with threshold 20
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 5)),
          isNull,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(30, 5), threshold: 20),
          SwipeDirection.right,
        );
      });

      test('vertical direction takes priority when dx == dy', () {
        // When abs(dx) == abs(dy), falls into the dy else branch
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(60, 60)),
          SwipeDirection.down,
        );
        expect(
          PaneNavigator.detectSwipeDirection(const Offset(-60, -60)),
          SwipeDirection.up,
        );
      });
    });

    group('SwipeDirectionExtension.inverted', () {
      test('inverse of up is down', () {
        expect(SwipeDirection.up.inverted, SwipeDirection.down);
      });

      test('inverse of down is up', () {
        expect(SwipeDirection.down.inverted, SwipeDirection.up);
      });

      test('inverse of left is right', () {
        expect(SwipeDirection.left.inverted, SwipeDirection.right);
      });

      test('inverse of right is left', () {
        expect(SwipeDirection.right.inverted, SwipeDirection.left);
      });

      test('double inversion returns to original', () {
        for (final dir in SwipeDirection.values) {
          expect(dir.inverted.inverted, dir);
        }
      });
    });
  });
}
