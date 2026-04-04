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

/// 特殊キーバー（HTMLデザイン仕様準拠）
///
/// VT100/xterm escape sequence方式でキーを送信するため、
/// PTYストリームに直接書き込める形式のエスケープシーケンスを生成する。
class SpecialKeysBar extends StatefulWidget {
  /// リテラルキー送信（通常の文字）
  final void Function(String key) onKeyPressed;

  /// 特殊キー送信（VT100エスケープシーケンス）
  final void Function(String sequence) onSpecialKeyPressed;

  final VoidCallback? onInputTap;
  final bool hapticFeedback;

  /// DirectInputモードが有効か
  final bool directInputEnabled;

  /// DirectInputモードのトグルコールバック
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

  /// 現在IME変換中かどうか
  bool _isComposing = false;

  /// IME composing中の最新テキスト（iOS重複検出用）
  /// iOSが自動確定時にcomposingテキストより長い確定テキストを返す場合、
  /// composingテキストを正とし余分な重複を除去する
  String? _lastComposingText;

  /// DirectInputモードでBackspace検出のためのsentinel文字（ゼロ幅スペース）
  /// iOS/iPadOSではTextField空の状態でBackspace押下時にKeyDownEventが
  /// 生成されないため、常にsentinelを保持して削除検出でBackspaceを検知する
  static const String _sentinel = '\u200B';

  /// sentinel リセット中の再入防止フラグ
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
    super.dispose();
  }

  /// DirectInput: テキスト変更時の処理
  /// sentinelアプローチでBackspaceを検出（iOS/iPadOS対応）
  void _onDirectInputChanged() {
    if (_isResettingController) return;

    final text = _directInputController.text;
    final value = _directInputController.value;

    // composingが空でない = IME変換中
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

    // Sentinelが削除された = Backspaceが押された（iOS/iPadOS対応）
    if (text.isEmpty) {
      _lastComposingText = null;
      _sendDirectBackspace();
      _resetToSentinel();
      return;
    }

    // Sentinelを除去して実際の入力テキストを取得
    final actualText = text.replaceAll(_sentinel, '');

    // 実際のテキストがあれば送信
    if (actualText.isNotEmpty) {
      // iOS重複検出: 確定テキストがcomposingテキストより長く、
      // composingテキストで始まる場合、iOSの重複挿入とみなしcomposingテキストを使用
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

      // 送信後にsentinelにリセット
      _resetToSentinel();
    }
  }

  /// DirectInput: ソフトウェアキーボードのEnter（送信）で呼ばれる
  void _onDirectInputSubmitted(String value) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed(Vt100Keys.enter);
    _resetToSentinel();
  }

  /// DirectInput: Backspaceキー送信
  void _sendDirectBackspace() {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onSpecialKeyPressed(Vt100Keys.backspace);
  }

  /// DirectInput: sentinelにリセット（Backspace検出用）
  ///
  /// _isResettingControllerの解除を次フレームまで遅延することで、
  /// iOSプラットフォームがIME確定時に送る遅延テキスト更新を吸収する。
  /// PostFrameCallbackでcontrollerが上書きされていれば再度sentinelにリセットする。
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
      // composing進行中ならiOSの入力を尊重して再リセットしない
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
            _buildModifierKeysRow(),
            _buildArrowKeysRow(),
            if (widget.directInputEnabled) _buildDirectInputRow(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// 上部の修飾キー行（ESC, TAB, CTRL, ALT, SHIFT, ENTER, S-RET, /, -）
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

  /// Shift+Enterキーボタン（Claude CodeのAcceptEdits等用）
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

  /// ENTERキーボタン（単体でEnterを送信）
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

  /// 下部の矢印キー + Inputボタン行
  Widget _buildArrowKeysRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // 矢印キー横並び: 左・上・下・右
          _buildArrowButton(Icons.arrow_left, Vt100Keys.left),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_up, Vt100Keys.up),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_drop_down, Vt100Keys.down),
          const SizedBox(width: 2),
          _buildArrowButton(Icons.arrow_right, Vt100Keys.right),
          const SizedBox(width: 8),
          // DirectInputモードトグルボタン
          _buildDirectInputToggle(),
          // DirectInput有効時: 数字キー(1-4)を右寄せで表示
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
          // DirectInput無効時: Inputボタンを表示
          if (!widget.directInputEnabled) ...[
            const SizedBox(width: 4),
            Expanded(child: _buildInputButton()),
          ],
        ],
      ),
    );
  }

  /// DirectInput専用行（入力フィールドのみ）
  /// RET/BSはネイティブキーボードのものを使用
  Widget _buildDirectInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: _buildDirectInputField(),
    );
  }

  /// DirectInputモードのトグルボタン
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

  /// DirectInput用テキストフィールド（リアルタイム送信）
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
            // LIVEインジケーター（左側に配置）
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
            // 入力フィールド
            Expanded(
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
          ],
        ),
    );
  }

  /// 特殊キーボタン（VT100エスケープシーケンスで送信）
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

  /// リテラルキーボタン（そのまま文字として送信）
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

  /// 数字キーボタン（DirectInput有効時に矢印キー行に表示）
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

  /// 特殊キーを送信（VT100エスケープシーケンス）
  void _sendSpecialKey(String key) {
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    String sequence = key; // Already a VT100 sequence from button tap

    // 特殊なケース: Shift+Tab → Back Tab (ESC [ Z)
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

  /// リテラルキーを送信（文字そのまま）
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

    // 修飾子なしの場合はリテラル送信
    widget.onKeyPressed(data);
  }
}
