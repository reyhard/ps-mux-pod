# Research: Terminal Width Auto-Resize

**Date**: 2026-01-11
**Feature**: Terminal Width Auto-Resize
**Status**: Complete

## Research Questions

### RQ-1: Dynamic font size changes in xterm

**Question**: xterm packagerunfont sizechange？

**Findings**:
- `TerminalView`  `textStyle`  `TerminalStyle` 
- `TerminalStyle`  `fontSize` （default14）
- font sizechange、new `TerminalStyle`  Widget build
- performance: TerminalView buildlightweight（internal）

**Decision**: `TerminalStyle`  `fontSize` dynamicchangebuildfont sizeadjust

**Rationale**: xterm packagestandard、adddependenciesnot needed

**Alternatives Considered**:
- Transform.scale  → 、low
- custom → 、xterm internalimplementdependency

---

### RQ-2: Monospaced Font Width Calculation

**Question**: screen widthpanecharacterscountfont size

**Findings**:
- widthfont、1characterswidth = fontSize × characterswidth
- JetBrains Mono characterswidth ≈ 0.6（）
- : `fontSize = screenWidth / (paneWidth × charWidthRatio)`
- Flutter  `TextPainter` characterswidthpossible

**Decision**: TextPainter characterswidth、font size

**Rationale**: font familypossible

**Code Example**:
```dart
double calculateFontSize(double screenWidth, int paneCharWidth, String fontFamily) {
  // TextPainter  1 characterswidth
  final painter = TextPainter(
    text: TextSpan(text: 'M', style: TextStyle(fontFamily: fontFamily, fontSize: 100)),
    textDirection: TextDirection.ltr,
  )..layout();

  final charWidthRatio = painter.width / 100;
  return screenWidth / (paneCharWidth * charWidthRatio);
}
```

---

### RQ-3: Pinch Gesture Implementation in Flutter

**Question**: pinchzoom

**Findings**:
- `GestureDetector`  `onScaleStart/Update/End` pinch
- `InteractiveViewer` （TerminalView integration）
- zoomin progress `Transform.scale` display、closefont sizeswitch

**Decision**: GestureDetector + state pinchmanagement、zoomclosefont sizeupdate

**Rationale**: 60fps possible、xterm integration

**Implementation Pattern**:
```dart
GestureDetector(
  onScaleStart: (details) => _startScale = _currentScale,
  onScaleUpdate: (details) {
    setState(() => _currentScale = _startScale * details.scale);
  },
  onScaleEnd: (details) {
    final newFontSize = (baseFontSize * _currentScale).clamp(minFontSize, maxFontSize);
    // font size、
  },
  child: Transform.scale(
    scale: _currentScale,
    child: TerminalView(...),
  ),
)
```

---

### RQ-4: Horizontal Scroll Implementation

**Question**: TerminalView scrollenabled

**Findings**:
- `TerminalView` scrollsupport
- `SingleChildScrollView`  wrap scrollpossible
- scrollstateretain、paneswitch

**Decision**: `SingleChildScrollView` (horizontal)  TerminalView  wrap

**Rationale**:  Flutter standardscrollbehaviorconsistency

**Code Structure**:
```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  physics: needsHorizontalScroll ? null : NeverScrollableScrollPhysics(),
  child: SizedBox(
    width: terminalWidth,  // paneWidth * charWidth
    child: TerminalView(...),
  ),
)
```

---

### RQ-5: Existing Settings Infrastructure

**Question**: minimumfont sizesettingsexistingintegration

**Findings**:
- `AppSettings`  `minFontSize` add
- `SettingsNotifier`  getter/setter add
- `shared_preferences` persist（existingpattern）
- Settings Screen MinFontSizeDialog add

**Decision**: existing `settings_provider.dart` extension

**Rationale**: existingpatternconsistencymaintain、code

---

## Technology Decisions Summary

| Topic | Decision | Confidence |
|-------|----------|------------|
| font sizechange | TerminalStyle.fontSize dynamicchange | High |
| characterswidth | TextPainter  | High |
| pinchzoom | GestureDetector + Transform.scale | High |
| scroll | SingleChildScrollView wrap | High |
| settingspersist | existing settings_provider extension | High |

## Dependencies

- xterm ^4.0.0 (existing)
- flutter_riverpod ^3.1.0 (existing)
- shared_preferences ^2.5.4 (existing)
- adddependency



