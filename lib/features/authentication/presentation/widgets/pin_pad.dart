import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Professional, fintech-grade inline PIN entry widget:
/// - 4 clean animated dot indicators.
/// - Tactile numeric keypad (1–9, optional biometric key, 0, backspace).
/// - Automatic submission upon entering the 4th digit.
/// - Physical keyboard support for desktop/web POS terminals.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.onSubmit,
    super.key,
    this.label = 'Ingiza PIN yako',
    this.digitsCount = 4,
    this.disabled = false,
    this.onBiometric,
  });

  /// Called with the completed PIN. Thrown errors surface as widget errors.
  final Future<void> Function(String pin) onSubmit;

  final String label;

  /// Number of digits for the PIN (default 4).
  final int digitsCount;

  /// Disables the whole pad (e.g. while verification runs).
  final bool disabled;

  /// Optional biometric callback for the bottom-left key.
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _submitting = false;

  bool get _locked => widget.disabled || _submitting;

  void _addDigit(String digit) {
    if (_locked || _pin.length >= widget.digitsCount) return;
    final next = _pin + digit;
    setState(() => _pin = next);
    if (next.length == widget.digitsCount) {
      _submit(next);
    }
  }

  void _backspace() {
    if (_locked || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _clear() {
    if (mounted) {
      setState(() => _pin = '');
    }
  }

  Future<void> _submit(String pinToSubmit) async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(pinToSubmit);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _pin = '';
        });
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_locked || event is! KeyDownEvent) return;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _addDigit(char);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.digitsCount; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                _PinDot(filled: i < _pin.length),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _PinKeypad(
            locked: _locked,
            onDigit: _addDigit,
            onBackspace: _backspace,
            onBiometric: widget.onBiometric,
          ),
        ],
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.primary : colors.surfaceContainerHighest,
        border: Border.all(
          color: filled ? colors.primary : colors.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.locked,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
  });

  final bool locked;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: _KeyButton(
                      label: digits[row * 3 + col],
                      onTap: () => onDigit(digits[row * 3 + col]),
                      locked: locked,
                    ),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: onBiometric != null
                    ? _KeyButton(
                        icon: Icons.fingerprint,
                        iconColor: Theme.of(context).colorScheme.primary,
                        iconSize: 28,
                        onTap: onBiometric!,
                        locked: locked,
                      )
                    : const SizedBox(height: 58),
              ),
              Expanded(
                child: _KeyButton(
                  label: '0',
                  onTap: () => onDigit('0'),
                  locked: locked,
                ),
              ),
              Expanded(
                child: _KeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                  locked: locked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    this.iconColor,
    this.iconSize = 22,
    required this.onTap,
    required this.locked,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = icon != null
        ? Icon(icon, size: iconSize, color: iconColor ?? colors.onSurface)
        : Text(
            label!,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: SizedBox(
        height: 56,
        child: Material(
          color: colors.surfaceContainerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: locked ? null : onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
