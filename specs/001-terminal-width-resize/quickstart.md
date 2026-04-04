# Quickstart: Terminal Width Auto-Resize

**Date**: 2026-01-11
**Feature**: Terminal Width Auto-Resize

## Overview

feature、tmux panewidth（characterscount）terminalfont sizeautomaticadjust。

## Key Components

### 1. FontCalculator (`lib/services/terminal/font_calculator.dart`)

font sizecount。

```dart
class FontCalculator {
  /// screen widthpanecharacterscountfont size
  ///
  /// [screenWidth] usepossiblewidth（）
  /// [paneCharWidth] panewidth（characterscount）
  /// [fontFamily] font family
  /// [minFontSize] minimumfont size（）
  ///
  /// Returns: (fontSize, needsScroll) 
  static ({double fontSize, bool needsScroll}) calculate({
    required double screenWidth,
    required int paneCharWidth,
    required String fontFamily,
    required double minFontSize,
  }) {
    if (paneCharWidth <= 0 || screenWidth <= 0) {
      return (fontSize: 14.0, needsScroll: false);
    }

    // TextPainter characterswidth
    final charWidthRatio = _measureCharWidthRatio(fontFamily);

    // : fontSize = screenWidth / (paneWidth × charWidthRatio)
    final calculatedSize = screenWidth / (paneCharWidth * charWidthRatio);

    if (calculatedSize >= minFontSize) {
      return (fontSize: calculatedSize, needsScroll: false);
    } else {
      return (fontSize: minFontSize, needsScroll: true);
    }
  }

  static double _measureCharWidthRatio(String fontFamily) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(fontFamily: fontFamily, fontSize: 100),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.width / 100;
  }
}
```

---

### 2. TerminalDisplayProvider (`lib/providers/terminal_display_provider.dart`)

Terminal Displaystatemanagement Riverpod Provider。

```dart
@freezed
class TerminalDisplayState with _$TerminalDisplayState {
  const factory TerminalDisplayState({
    @Default(80) int paneWidth,
    @Default(24) int paneHeight,
    @Default(0.0) double screenWidth,
    @Default(14.0) double calculatedFontSize,
    @Default(false) bool needsHorizontalScroll,
    @Default(0.0) double horizontalScrollOffset,
    @Default(1.0) double zoomScale,
    @Default(false) bool isZooming,
  }) = _TerminalDisplayState;
}

class TerminalDisplayNotifier extends Notifier<TerminalDisplayState> {
  @override
  TerminalDisplayState build() => const TerminalDisplayState();

  /// paneinformationupdate
  void updatePane(TmuxPane pane) {
    state = state.copyWith(
      paneWidth: pane.width,
      paneHeight: pane.height,
    );
    _recalculateFontSize();
  }

  /// widthupdate
  void updateScreenWidth(double width) {
    state = state.copyWith(screenWidth: width);
    _recalculateFontSize();
  }

  /// pinchzoomstart
  void startZoom() {
    state = state.copyWith(isZooming: true);
  }

  /// pinchzoomupdate
  void updateZoom(double scale) {
    state = state.copyWith(zoomScale: scale);
  }

  /// pinchzoomclose
  void endZoom() {
    // zoomfont size
    final newFontSize = state.calculatedFontSize * state.zoomScale;
    state = state.copyWith(
      calculatedFontSize: newFontSize.clamp(minFontSize, 48.0),
      zoomScale: 1.0,
      isZooming: false,
    );
    _recalculateFontSize();
  }

  void _recalculateFontSize() {
    final settings = ref.read(settingsProvider);
    final result = FontCalculator.calculate(
      screenWidth: state.screenWidth,
      paneCharWidth: state.paneWidth,
      fontFamily: settings.fontFamily,
      minFontSize: settings.minFontSize,
    );

    state = state.copyWith(
      calculatedFontSize: result.fontSize,
      needsHorizontalScroll: result.needsScroll,
    );
  }
}

final terminalDisplayProvider =
    NotifierProvider<TerminalDisplayNotifier, TerminalDisplayState>(
  () => TerminalDisplayNotifier(),
);
```

---

### 3. ScalableTerminal (`lib/screens/terminal/Widgets/scalable_terminal.dart`)

pinchzoomscrollintegration TerminalView 。

```dart
class ScalableTerminal extends ConsumerWidget {
  final Terminal terminal;
  final TerminalController controller;
  final TerminalTheme theme;

  const ScalableTerminal({
    super.key,
    required this.terminal,
    required this.controller,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayState = ref.watch(terminalDisplayProvider);
    final settings = ref.watch(settingsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // widthupdate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(terminalDisplayProvider.notifier)
              .updateScreenWidth(constraints.maxWidth);
        });

        final terminalView = TerminalView(
          terminal,
          controller: controller,
          theme: theme,
          textStyle: TerminalStyle(
            fontSize: displayState.isZooming
                ? displayState.calculatedFontSize * displayState.zoomScale
                : displayState.calculatedFontSize,
            fontFamily: settings.fontFamily,
          ),
        );

        Widget content = displayState.needsHorizontalScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _calculateTerminalWidth(displayState, settings),
                  child: terminalView,
                ),
              )
            : terminalView;

        return GestureDetector(
          onScaleStart: (_) {
            ref.read(terminalDisplayProvider.notifier).startZoom();
          },
          onScaleUpdate: (details) {
            ref.read(terminalDisplayProvider.notifier)
                .updateZoom(details.scale);
          },
          onScaleEnd: (_) {
            ref.read(terminalDisplayProvider.notifier).endZoom();
          },
          child: content,
        );
      },
    );
  }

  double _calculateTerminalWidth(
    TerminalDisplayState displayState,
    AppSettings settings,
  ) {
    final charWidthRatio = 0.6; // JetBrains Mono approximation
    return displayState.paneWidth *
        charWidthRatio *
        displayState.calculatedFontSize;
  }
}
```

---

### 4. Settings Extension

`AppSettings` Settings Screenextension。

```dart
// settings_provider.dart add
class AppSettings {
  // ... existing ...
  final double minFontSize;        // new
  final bool autoFitEnabled;       // new

  const AppSettings({
    // ... existing ...
    this.minFontSize = 8.0,
    this.autoFitEnabled = true,
  });
}
```

---

## Usage Flow

1. **paneselect**:
   ```dart
   final pane = tmuxState.activePane;
   ref.read(terminalDisplayProvider.notifier).updatePane(pane);
   ```

2. **screensizechange**:
   - `LayoutBuilder` automatic `updateScreenWidth()` 

3. **pinchzoom**:
   - `GestureDetector` automaticzoomstatemanagement

4. **settingschange**:
   - `settingsProvider` change watch automaticre

---

## Testing Strategy

### Unit Tests

```dart
// font_calculator_test.dart
void main() {
  group('FontCalculator', () {
    test('calculates font size for 80 char pane', () {
      final result = FontCalculator.calculate(
        screenWidth: 400.0,
        paneCharWidth: 80,
        fontFamily: 'JetBrains Mono',
        minFontSize: 8.0,
      );

      expect(result.fontSize, closeTo(8.33, 0.1));
      expect(result.needsScroll, isFalse);
    });

    test('enables scroll when font would be too small', () {
      final result = FontCalculator.calculate(
        screenWidth: 400.0,
        paneCharWidth: 200,
        fontFamily: 'JetBrains Mono',
        minFontSize: 8.0,
      );

      expect(result.fontSize, equals(8.0));
      expect(result.needsScroll, isTrue);
    });
  });
}
```

### Widget Tests

```dart
// scalable_terminal_test.dart
void main() {
  testWidgets('pinch zoom changes font size', (tester) async {
    // pinchfont sizechangeverify
  });

  testWidgets('horizontal scroll enabled for wide panes', (tester) async {
    // panescrollenabledverify
  });
}
```

---

## File Checklist

| File | Type | Status |
|------|------|--------|
| `lib/services/terminal/font_calculator.dart` | New | Create |
| `lib/providers/terminal_display_provider.dart` | New | Create |
| `lib/screens/terminal/Widgets/scalable_terminal.dart` | New | Create |
| `lib/providers/settings_provider.dart` | Modify | Add minFontSize, autoFitEnabled |
| `lib/screens/settings/settings_screen.dart` | Modify | Add min font size setting |
| `lib/Widgets/dialogs/min_font_size_dialog.dart` | New | Create |
| `lib/screens/terminal/terminal_screen.dart` | Modify | Use ScalableTerminal |
| `test/services/terminal/font_calculator_test.dart` | New | Create |
| `test/providers/terminal_display_provider_test.dart` | New | Create |
| `test/screens/terminal/scalable_terminal_test.dart` | New | Create |



