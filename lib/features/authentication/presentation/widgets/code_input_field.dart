import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A code entry field for short numeric strings: TOTP codes (6 digits) and
/// recovery codes (10 characters).
///
/// Uses [TextInputType.number] with `inputFormatters` for the numeric case so
/// the platform keypad is the numeric one — on a cheap handset that is the
/// difference between usable and not. Recovery codes contain letters, so that
/// case falls back to a text keypad while still forcing uppercase.
class CodeInputField extends StatefulWidget {
  const CodeInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.digitCount = 6,
    this.allowLetters = false,
    this.label,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;

  /// Expected length, enforced as a hard maximum so an over-long value cannot
  /// be typed at all.
  final int digitCount;

  /// Whether the code may contain letters (recovery codes do; TOTP codes do
  /// not). Drives both the keypad type and the input formatter, so the two
  /// code kinds are typed correctly rather than merely tolerated.
  final bool allowLetters;

  final String? label;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  @override
  Widget build(BuildContext context) {
    final formatters = <TextInputFormatter>[
      LengthLimitingTextInputFormatter(widget.digitCount),
      if (widget.allowLetters)
        _upperCaseFormatter
      else
        FilteringTextInputFormatter.digitsOnly,
    ];

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: widget.allowLetters
          ? TextInputType.visiblePassword
          : TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: formatters,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        letterSpacing: widget.allowLetters ? 2 : 8,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}

final _upperCaseFormatter = _UpperCaseFormatter();

/// Forces uppercase as the user types so a lower-case recovery code (which the
/// user may have copied from an email) is never rejected for casing alone.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}
