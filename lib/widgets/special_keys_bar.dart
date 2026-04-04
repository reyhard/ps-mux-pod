import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/design_colors.dart';

/// VT100/xterm escape sequence constants for special keys.
///
/// Used by [SpecialKeysBar] to produce raw escape sequences that can be
/// written directly to the PTY stream.
class Vt100Keys {
  static const escape = '\x1b';
  static const enter = '\r';
  static const tab = '\t';
  static const backspace = '\x7f';
  static const delete = '\x1b[3~';
  static const insert = '\x1b[2~';

  static const up = '\x1b[A';
  static const down = '\x1b[B';
  static const right = '\x1b[C';
  static const left = '\x1b[D';

  static const home = '\x1b[H';
  static const end = '\x1b[F';
  static const pageUp = '\x1b[5~';
  static const pageDown = '\x1b[6~';

  static const f1 = '\x1bOP';
  static const f2 = '\x1bOQ';
  static const f3 = '\x1bOR';
  static const f4 = '\x1bOS';
  static const f5 = '\x1b[15~';
  static const f6 = '\x1b[17~';
  static const f7 = '\x1b[18~';
  static const f8 = '\x1b[19~';
  static const f9 = '\x1b[20~';
  static const f10 = '\x1b[21~';
  static const f11 = '\x1b[23~';
  static const f12 = '\x1b[24~';

  static const backTab = '\x1b[Z'; // Shift+Tab

  /// Ctrl+letter -> control character (Ctrl+A = 0x01, ..., Ctrl+Z = 0x1A)
  static String ctrl(String letter) {
    final code = letter.toUpperCase().codeUnitAt(0) - 0x40;
    return String.fromCharCode(code);
  }

  /// Alt (Meta) prefix: ESC + key
  static String alt(String key) => '\x1b$key';
}

/// Special keys bar (follows HTML design spec)
///
/// Sends keys as VT100/xterm escape sequences,
/// generating escape sequences that can be written directly to the PTY stream.
class SpecialKeysBar extends StatefulWidget {
  /// Literal key send (normal characters)
  final void Function(String key) onKeyPressed;

  /// Special key send (VT100 escape sequences)
  final void Function(String sequence) onSpecialKeyPressed;

  final VoidCallback? onInputTap;

  final bool hapticFeedback;

  /// Whether DirectInput mode is enabled
  final bool directInputEnabled;

  /// DirectInput mode toggle callback
  final VoidCallback? onDirectInputToggle;

  const SpecialKeysBar({
    super.key,
    required this.onKeyPressed,
    required this.onSpecialKeyPressed,
    this.onInputTap,
    this.hapticFeedback = true,
    this.directInputEnabled = false,
    this.onDirectInputToggle,
  });

  @override
  State<SpecialKeysBar> createState() => _SpecialKeysBarState();
}

class _SpecialKeysBarState extends State<SpecialKeysBar> {
  bool _ctrlPressed = false;
  bool _altPressed = false;
  bool _shiftPressed = false;
  final TextEditingController _directInputController = TextEditingController();
  final FocusNode _directInputFocusNode = FocusNode();

  // RAW input mode — IME-free keyboard that sends each keystroke directly
  bool _rawInputEnabled = false;
  final TextEditingController _rawInputController = TextEditingController();
  final FocusNode _rawInputFocusNode = FocusNode();

  /// Whether IME composition is currently active
  bool _isComposing = false;

  /// Latest text during IME composing (for iOS duplicate detection)
  /// When iOS returns committed text longer than composing text during auto-commit,
  /// treat the composing text as authoritative and remove the extra duplicate
  String? _lastComposingText;

  /// Sentinel character (zero-width space) for Backspace detection in DirectInput mode
  /// On iOS/iPadOS, pressing Backspace when TextField is empty does not generate
  /// a KeyDownEvent, so we always keep a sentinel to detect Backspace via deletion
  static const String _sentinel = '\u200B';

  /// Re-entry guard flag during sentinel reset
  bool _isResettingController = false;

  @override
  void initState() {
    super.initState();
    if (widget.directInputEnabled) {
      _directInputController.value = TextEditingValue(
        text: _sentinel,
        selection: TextSelection.collapsed(offset: _sentinel.length),
      );
    }
    _directInputController.addListener(_onDirectInputChanged);
  }

  @override
  void didUpdateWidget(SpecialKeysBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.directInputEnabled && !oldWidget.directInputEnabled) {
      _resetToSentinel();
    } else if (!widget.directInputEnabled && oldWidget.directInputEnabled) {
      _isResettingController = true;
      _directInputController.clear();
      _isResettingController = false;
    }
  }

  @override
  void dispose() {
    _directInputController.removeListener(_onDirectInputChanged);
    _directInputController.dispose();
    _directInputFocusNode.dispose();
    _rawInputController.dispose();
    _rawInputFocusNode.dispose();
    super.dispose();
  }

  /// DirectInput: handler for text changes
  /// Detects Backspace via the sentinel approach (iOS/iPadOS compatible)
  void _onDirectInputChanged() {
    if (_isResettingController) return;

    final text = _directInputController.text;
    final value = _directInputController.value;

    // Non-empty composing = IME composition in progress
    _isComposing = value.composing.isValid && !value.composing.isCollapsed;

    if (_isComposing) {
      // Record composing text for iOS duplicate detection
      _lastComposingText = text.replaceAll(_sentinel, '');

      // Samsung IME composing workaround:
      // Samsung (and some Android IMEs) treat English letters as composing,
      // so composing=false may NEVER arrive while the user keeps typing.
      // When a modifier (CTRL/ALT) is active, intercept the first composing
      // character immediately instead of waiting for composing to end.
      // Guards:
      //   - length == 1: only the first composing char (avoids accumulated repeats)
      //   - ASCII letter regex: don't intercept Korean (ㅊ) or other non-ASCII composing
      if ((_ctrlPressed || _altPressed) && _lastComposingText!.length == 1) {
        final char = _lastComposingText!;
        if (RegExp(r'^[A-Za-z]$').hasMatch(char)) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
          String sequence = char;
          if (_ctrlPressed) {
            sequence = Vt100Keys.ctrl(char);
            setState(() => _ctrlPressed = false);
          }
          if (_altPressed) {
            sequence = Vt100Keys.alt(sequence);
            setState(() => _altPressed = false);
          }
          widget.onSpecialKeyPressed(sequence);
          _lastComposingText = null;
          _resetToSentinel();
          return;
        }
      }

      return;
    }

    // Sentinel was deleted = Backspace was pressed (iOS/iPadOS compatible)
    if (text.isEmpty) {
      _lastComposingText = null;
      _sendDirectBackspace();
      _resetToSentinel();
      return;
    }

    // Remove sentinel to get the actual input text
    final actualText = text.replaceAll(_sentinel, '');

    // Send if there is actual text
    if (actualText.isNotEmpty) {
      // iOS duplicate detection: if committed text is longer than composing text
      // and starts with composing text, treat as iOS duplicate insertion and use composing text
      String textToSend = actualText;
      if (_lastComposingText != null &&
          actualText.length > _lastComposingText!.length &&
          actualText.startsWith(_lastComposingText!)) {
        textToSend = _lastComposingText!;
      }
      _lastComposingText = null;

      // Send modifier+key when CTRL/ALT is active (non-composing path)
      // This handles IMEs that commit without composing (e.g. Gboard English)
      // VT100 format: Ctrl+letter -> control char, Alt+key -> ESC prefix
      if ((_ctrlPressed || _altPressed) &&
          textToSend.length == 1 &&
          RegExp(r'^[A-Za-z]$').hasMatch(textToSend)) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        String sequence = textToSend;
        if (_ctrlPressed) {
          sequence = Vt100Keys.ctrl(textToSend);
          setState(() => _ctrlPressed = false);
        }
        if (_altPressed) {
          sequence = Vt100Keys.alt(sequence);
          setState(() => _altPressed = false);
        }
        widget.onSpecialKeyPressed(sequence);
      } else {
        widget.onKeyPressed(textToSend);
      }

      // Reset to sentinel after sending
      _resetToSentinel();
    }
  }

  /// DirectInput: called when Enter (submit) is pressed on the software keyboard
  void _onDirectInputSubmitted(String value) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed(Vt100Keys.enter);
    _resetToSentinel();
  }

  /// DirectInput: send Backspace key
  void _sendDirectBackspace() {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed(Vt100Keys.backspace);
  }

  /// DirectInput: handle hardware keyboard key events
  /// Sends keys with Ctrl/Alt modifiers and special keys as VT100 escape sequences
  KeyEventResult _handleDirectInputKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    // Special keys → VT100 escape sequences
    final specialMap = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.escape: Vt100Keys.escape,
      LogicalKeyboardKey.tab: shift ? Vt100Keys.backTab : Vt100Keys.tab,
      LogicalKeyboardKey.arrowUp: Vt100Keys.up,
      LogicalKeyboardKey.arrowDown: Vt100Keys.down,
      LogicalKeyboardKey.arrowLeft: Vt100Keys.left,
      LogicalKeyboardKey.arrowRight: Vt100Keys.right,
      LogicalKeyboardKey.home: Vt100Keys.home,
      LogicalKeyboardKey.end: Vt100Keys.end,
      LogicalKeyboardKey.pageUp: Vt100Keys.pageUp,
      LogicalKeyboardKey.pageDown: Vt100Keys.pageDown,
      LogicalKeyboardKey.delete: Vt100Keys.delete,
      LogicalKeyboardKey.insert: Vt100Keys.insert,
      LogicalKeyboardKey.f1: Vt100Keys.f1,
      LogicalKeyboardKey.f2: Vt100Keys.f2,
      LogicalKeyboardKey.f3: Vt100Keys.f3,
      LogicalKeyboardKey.f4: Vt100Keys.f4,
      LogicalKeyboardKey.f5: Vt100Keys.f5,
      LogicalKeyboardKey.f6: Vt100Keys.f6,
      LogicalKeyboardKey.f7: Vt100Keys.f7,
      LogicalKeyboardKey.f8: Vt100Keys.f8,
      LogicalKeyboardKey.f9: Vt100Keys.f9,
      LogicalKeyboardKey.f10: Vt100Keys.f10,
      LogicalKeyboardKey.f11: Vt100Keys.f11,
      LogicalKeyboardKey.f12: Vt100Keys.f12,
    };

    if (specialMap.containsKey(key)) {
      String seq = specialMap[key]!;
      if (alt) seq = Vt100Keys.alt(seq);
      widget.onSpecialKeyPressed(seq);
      return KeyEventResult.handled;
    }

    // Ctrl+letter or Alt+letter → send as control/meta character
    if ((ctrl || alt) && key.keyLabel.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(key.keyLabel)) {
      String seq = key.keyLabel;
      if (ctrl) seq = Vt100Keys.ctrl(seq);
      if (alt) seq = Vt100Keys.alt(seq);
      widget.onSpecialKeyPressed(seq);
      return KeyEventResult.handled;
    }

    // Let TextField handle normal text input
    return KeyEventResult.ignored;
  }

  /// DirectInput: reset to sentinel (for Backspace detection)
  ///
  /// Delays releasing _isResettingController until the next frame to absorb
  /// delayed text updates sent by the iOS platform during IME commit.
  /// If the controller has been overwritten by PostFrameCallback, reset to sentinel again.
  void _resetToSentinel() {
    _isResettingController = true;
    _directInputController.value = TextEditingValue(
      text: _sentinel,
      selection: TextSelection.collapsed(offset: _sentinel.length),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentValue = _directInputController.value;
      final hasActiveComposing = currentValue.composing.isValid &&
          !currentValue.composing.isCollapsed;
      // If composing is in progress, respect iOS input and skip re-reset
      if (!hasActiveComposing && _directInputController.text != _sentinel) {
        _directInputController.value = TextEditingValue(
          text: _sentinel,
          selection: TextSelection.collapsed(offset: _sentinel.length),
        );
      }
      _isResettingController = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignColors.footerBackground : DesignColors.footerBackgroundLight,
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavigationKeysRow(),
            _buildModifierKeysRow(),
            _buildArrowKeysRow(),
            if (_rawInputEnabled) _buildRawInputRow(),
            if (widget.directInputEnabled && !_rawInputEnabled) _buildDirectInputRow(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Navigation keys row (PgUp, PgDn, Home, End, Del, Ins)
  Widget _buildNavigationKeysRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          _buildSpecialKeyButton('PgUp', Vt100Keys.pageUp),
          _buildSpecialKeyButton('PgDn', Vt100Keys.pageDown),
          _buildSpecialKeyButton('Home', Vt100Keys.home),
          _buildSpecialKeyButton('End', Vt100Keys.end),
          _buildSpecialKeyButton('Del', Vt100Keys.delete),
          _buildSpecialKeyButton('Ins', Vt100Keys.insert),
        ],
      ),
    );
  }

  /// Upper modifier keys row (ESC, TAB, CTRL, ALT, SHIFT, ENTER, S-RET, /, -)
  Widget _buildModifierKeysRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: isDark ? DesignColors.surfaceDark : DesignColors.surfaceLight,
      child: Row(
        children: [
          _buildSpecialKeyButton('ESC', Vt100Keys.escape),
          _buildSpecialKeyButton('TAB', Vt100Keys.tab),
          _buildModifierButton('CTRL', _ctrlPressed, () {
            setState(() => _ctrlPressed = !_ctrlPressed);
          }),
          _buildModifierButton('ALT', _altPressed, () {
            setState(() => _altPressed = !_altPressed);
          }),
          _buildModifierButton('SHIFT', _shiftPressed, () {
            setState(() => _shiftPressed = !_shiftPressed);
          }),
          _buildEnterKeyButton(),
          _buildShiftEnterKeyButton(),
          _buildLiteralKeyButton('/', '/'),
          _buildLiteralKeyButton('-', '-'),
        ],
      ),
    );
  }

  /// Shift+Enter key button (for Claude Code AcceptEdits, etc.)
  Widget _buildShiftEnterKeyButton() {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey(Vt100Keys.enter),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: DesignColors.secondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: DesignColors.secondary.withValues(alpha: 0.5), width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'S-RET',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: DesignColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ENTER key button (sends Enter on its own)
  Widget _buildEnterKeyButton() {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey(Vt100Keys.enter),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: DesignColors.primary.withValues(alpha: 0.5), width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_return,
                  size: 12,
                  color: DesignColors.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  'RET',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lower arrow keys + Input button row
  Widget _buildArrowKeysRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Arrow keys in a row: Left, Up, Down, Right
          _buildArrowButton(Icons.arrow_left, Vt100Keys.left),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_up, Vt100Keys.up),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_down, Vt100Keys.down),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_right, Vt100Keys.right),
          const SizedBox(width: 8),
          // Raw input mode button (opens TerminalView's native keyboard)
          _buildRawInputButton(),
          const SizedBox(width: 2),
          // DirectInput mode toggle button (LIVE mode with IME/dictionary)
          _buildDirectInputToggle(),
          // When DirectInput is enabled: show number keys (1-4) right-aligned
          if (widget.directInputEnabled) ...[
            const Spacer(),
            _buildNumberKeyButton('1'),
            const SizedBox(width: 2),
            _buildNumberKeyButton('2'),
            const SizedBox(width: 2),
            _buildNumberKeyButton('3'),
            const SizedBox(width: 2),
            _buildNumberKeyButton('4'),
          ],
          // When DirectInput is disabled: show Input button
          if (!widget.directInputEnabled) ...[
            const SizedBox(width: 4),
            Expanded(child: _buildInputButton()),
          ],
        ],
      ),
    );
  }

  /// RAW input row — IME-free keyboard, each keystroke sent immediately
  Widget _buildRawInputRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: DesignColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DesignColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // RAW indicator
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: DesignColors.warning.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'RAW',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Hidden input field — no IME, no suggestions, each key sent immediately
            Expanded(
              child: Focus(
                onKeyEvent: _handleDirectInputKeyEvent,
                child: TextField(
                  controller: _rawInputController,
                  focusNode: _rawInputFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  onChanged: (text) {
                    if (text.isEmpty) {
                      // Backspace was pressed
                      widget.onSpecialKeyPressed(Vt100Keys.backspace);
                    } else {
                      // Send each character immediately
                      widget.onKeyPressed(text);
                      _rawInputController.clear();
                    }
                  },
                  onSubmitted: (_) {
                    widget.onSpecialKeyPressed(Vt100Keys.enter);
                    _rawInputFocusNode.requestFocus();
                  },
                  textInputAction: TextInputAction.send,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Raw input...',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: DesignColors.warning.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DirectInput dedicated row (input field only)
  /// RET/BS use the native keyboard keys
  Widget _buildDirectInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: _buildDirectInputField(),
    );
  }

  /// Raw input button — toggles IME-free keyboard mode
  /// Each keystroke goes directly to terminal without composing/dictionary
  Widget _buildRawInputButton() {
    return GestureDetector(
      onTap: () {
        if (widget.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        setState(() {
          _rawInputEnabled = !_rawInputEnabled;
          // Disable LIVE mode when RAW is activated
          if (_rawInputEnabled && widget.directInputEnabled) {
            widget.onDirectInputToggle?.call();
          }
        });
        if (_rawInputEnabled) {
          // Focus the raw input field after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _rawInputFocusNode.requestFocus();
          });
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _rawInputEnabled
              ? DesignColors.warning.withValues(alpha: 0.3)
              : DesignColors.keyBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _rawInputEnabled
                ? DesignColors.warning.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Text(
            'RAW',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: _rawInputEnabled ? DesignColors.warning : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  /// DirectInput mode toggle button
  Widget _buildDirectInputToggle() {
    final isEnabled = widget.directInputEnabled;
    return GestureDetector(
      onTap: () {
        if (widget.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        widget.onDirectInputToggle?.call();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? DesignColors.success.withValues(alpha: 0.3)
              : DesignColors.keyBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isEnabled
                ? DesignColors.success.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Icon(
            isEnabled ? Icons.flash_on : Icons.flash_off,
            size: 18,
            color: isEnabled ? DesignColors.success : Colors.white70,
          ),
        ),
      ),
    );
  }

  /// DirectInput text field (real-time sending)
  Widget _buildDirectInputField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
        height: 40,
        decoration: BoxDecoration(
          color: DesignColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: DesignColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // LIVE indicator (placed on the left)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: DesignColors.success.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: DesignColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: DesignColors.success.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Input field (hardware keyboard shortcuts intercepted via onKeyEvent)
            Expanded(
              child: Focus(
                onKeyEvent: _handleDirectInputKeyEvent,
                child: TextField(
                  controller: _directInputController,
                  focusNode: _directInputFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _onDirectInputSubmitted,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type here...',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: DesignColors.success.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  /// Special key button (sends VT100 escape sequences)
  Widget _buildSpecialKeyButton(String label, String vt100Key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendSpecialKey(vt100Key),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.black : Colors.grey.shade400, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Literal key button (sends the character as-is)
  Widget _buildLiteralKeyButton(String label, String key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: () => _sendLiteralKey(key),
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.black : Colors.grey.shade400, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifierButton(String label, bool isPressed, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.hapticFeedback) {
            HapticFeedback.lightImpact();
          }
        },
        onTap: onPressed,
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isPressed ? colorScheme.primary : (isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight),
            borderRadius: BorderRadius.circular(4),
            border: Border(
              bottom: BorderSide(
                color: isPressed ? colorScheme.primary : (isDark ? Colors.black : Colors.grey.shade400),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPressed ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, String vt100Key) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTap: () => _sendSpecialKey(vt100Key),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  /// Number key button (shown in the arrow keys row when DirectInput is enabled)
  Widget _buildNumberKeyButton(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTap: () => _sendLiteralKey(label),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? DesignColors.keyBackground : DesignColors.keyBackgroundLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputButton() {
    return GestureDetector(
      onTap: widget.onInputTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: DesignColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: DesignColors.primary.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Icons.keyboard,
              size: 16,
              color: DesignColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Input...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: DesignColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: DesignColors.primary.withValues(alpha: 0.1)),
              ),
              child: Text(
                'cmd',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: DesignColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Send a special key (VT100 escape sequence)
  void _sendSpecialKey(String key) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    String sequence = key; // Already a VT100 sequence from button tap

    // Special case: Shift+Tab -> Back Tab (ESC [ Z)
    if (_shiftPressed && key == Vt100Keys.tab) {
      setState(() => _shiftPressed = false);
      if (_ctrlPressed) setState(() => _ctrlPressed = false);
      if (_altPressed) setState(() => _altPressed = false);
      widget.onSpecialKeyPressed(Vt100Keys.backTab);
      return;
    }

    // Apply sticky modifiers
    if (_shiftPressed) {
      setState(() => _shiftPressed = false);
      // Shift is consumed but does not alter the VT100 sequence for most keys
      // (arrow keys, function keys, etc. don't have a standard shift variant
      // in basic VT100; the key is sent as-is)
    }
    if (_ctrlPressed) {
      // Ctrl+letter -> control character
      if (key.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(key)) {
        sequence = Vt100Keys.ctrl(key);
      }
      setState(() => _ctrlPressed = false);
    }
    if (_altPressed) {
      sequence = Vt100Keys.alt(sequence);
      setState(() => _altPressed = false);
    }

    widget.onSpecialKeyPressed(sequence);
  }

  /// Send a literal key (character as-is)
  void _sendLiteralKey(String key) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    String data = key;

    // Reset shift (literal keys don't need shift VT100 encoding)
    if (_shiftPressed) {
      setState(() => _shiftPressed = false);
    }

    if (_ctrlPressed && key.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(key)) {
      data = Vt100Keys.ctrl(key);
      setState(() => _ctrlPressed = false);
      if (_altPressed) {
        data = Vt100Keys.alt(data);
        setState(() => _altPressed = false);
      }
      widget.onSpecialKeyPressed(data);
      return;
    }

    if (_altPressed && key.length == 1) {
      data = Vt100Keys.alt(key);
      setState(() => _altPressed = false);
      widget.onSpecialKeyPressed(data);
      return;
    }

    // Send as literal when no modifiers are active
    widget.onKeyPressed(data);
  }
}
