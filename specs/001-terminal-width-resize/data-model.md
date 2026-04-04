# Data Model: Terminal Width Auto-Resize

**Date**: 2026-01-11
**Feature**: Terminal Width Auto-Resize

## Entity Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         AppSettings                         │
│  (existing - extension)                                               │
├─────────────────────────────────────────────────────────────┤
│ + fontSize: double (existing)                                   │
│ + fontFamily: String (existing)                                 │
│ + minFontSize: double (new) ─── Default: 8.0              │
│ + autoFitEnabled: bool (new) ─── Default: true            │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ provides settings
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   TerminalDisplayState                      │
│  (new - Riverpod State)                                    │
├─────────────────────────────────────────────────────────────┤
│ + paneWidth: int              ─── tmux pane_width (characterscount)  │
│ + paneHeight: int             ─── tmux pane_height (rows)   │
│ + screenWidth: double         ─── usepossiblewidth     │
│ + calculatedFontSize: double  ─── font size   │
│ + effectiveFontSize: double   ─── font size   │
│ + needsHorizontalScroll: bool ─── scrollrequired       │
│ + horizontalScrollOffset: double ─── scroll     │
│ + zoomScale: double           ─── pinchzoom (1.0=)│
│ + isZooming: bool             ─── zoomoperationin progress            │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ uses
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      TmuxPane (existing)                        │
├─────────────────────────────────────────────────────────────┤
│ + index: int                                                │
│ + id: String                                                │
│ + active: bool                                              │
│ + width: int      ◄── pane_width (characterscount)                   │
│ + height: int     ◄── pane_height (rows)                    │
│ + cursorX: int                                              │
│ + cursorY: int                                              │
└─────────────────────────────────────────────────────────────┘
```

## Entity Definitions

### AppSettings (existing - extension)

appallsettingsmanagement。

**new**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| minFontSize | double | 8.0 | automaticadjustminimumfont size (px) |
| autoFitEnabled | bool | true | panewidthautomatic |

**Validation Rules**:
- minFontSize: 4.0 <= value <= 24.0
- autoFitEnabled: boolean

**Persistence**: shared_preferences (existingpattern)

---

### TerminalDisplayState (new)

Terminal Displaydynamicstatemanagement。Riverpod  StateNotifier management。

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| paneWidth | int | 80 | tmux panewidth（characterscount） |
| paneHeight | int | 24 | tmux paneheight（rows） |
| screenWidth | double | 0.0 | usepossiblewidth（） |
| calculatedFontSize | double | 14.0 | font size |
| effectiveFontSize | double | 14.0 | font size |
| needsHorizontalScroll | bool | false | scrollrequired |
| horizontalScrollOffset | double | 0.0 | scroll |
| zoomScale | double | 1.0 | pinchzoom |
| isZooming | bool | false | zoomoperationin progress |

**Computed Properties**:

```dart
/// font size
double get effectiveFontSize {
  if (isZooming) {
    return calculatedFontSize * zoomScale;
  }
  return max(calculatedFontSize, minFontSize);
}

/// scrollrequired
bool get needsHorizontalScroll {
  return calculatedFontSize < minFontSize;
}

/// terminaldisplaywidth（）
double get terminalWidth {
  return paneWidth * charWidth * effectiveFontSize;
}
```

**State Transitions**:

```
[Initial] ──────► [Pane Selected] ──────► [Font Calculated]
                        │                        │
                        │                        ▼
                        │               [Scroll Enabled if needed]
                        │
                        └────────► [Pinch Start] ──► [Zooming] ──► [Pinch End]
                                                                      │
                                                                      ▼
                                                              [Font Recalculated]
```

---

### TmuxPane (existing - change)

tmux paneinformation。existing `width`  `height` 。

---

## Relationships

1. **AppSettings → TerminalDisplayState**: settings（minFontSize, autoFitEnabled）
2. **TmuxPane → TerminalDisplayState**: pane_width, pane_height 
3. **TerminalDisplayState → TerminalView**: effectiveFontSize 

## State Flow

```
User selects pane
       │
       ▼
TmuxPane.width/height ──────────────────────┐
       │                                    │
       ▼                                    ▼
TerminalDisplayState.updatePane()    screenWidth (from LayoutBuilder)
       │                                    │
       ├────────────────────────────────────┘
       │
       ▼
FontCalculator.calculate(screenWidth, paneWidth, fontFamily)
       │
       ▼
calculatedFontSize = result
       │
       ▼
effectiveFontSize = max(calculatedFontSize, minFontSize)
       │
       ├─── if calculatedFontSize < minFontSize ──► needsHorizontalScroll = true
       │
       ▼
TerminalView rebuilds with new fontSize
```



