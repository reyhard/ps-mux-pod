import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks terminal typing while still allowing standard selection shortcuts.
///
/// This keeps the terminal read-only for regular key presses, but lets xterm's
/// built-in copy/select-all actions run when the terminal has focus.
KeyEventResult blockTerminalTypingButAllowSelectionShortcuts(
  FocusNode _,
  KeyEvent event,
) {
  if (_isCopySelectionShortcut(event) || _isSelectAllShortcut(event)) {
    return KeyEventResult.ignored;
  }

  return KeyEventResult.handled;
}

bool _isCopySelectionShortcut(KeyEvent event) {
  if (event.logicalKey != LogicalKeyboardKey.keyC) {
    return false;
  }

  if (_isApplePlatform) {
    return HardwareKeyboard.instance.isMetaPressed;
  }

  return HardwareKeyboard.instance.isControlPressed &&
      HardwareKeyboard.instance.isShiftPressed;
}

bool _isSelectAllShortcut(KeyEvent event) {
  if (event.logicalKey != LogicalKeyboardKey.keyA) {
    return false;
  }

  return _isApplePlatform
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;
}

bool get _isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
