import 'package:flutter/material.dart';

/// M-Pesa-style inline PIN entry: a row of dot indicators plus a numeric
/// keypad (1–9, 0, backspace, confirm).
///
/// Unlike a text field it feels like a security prompt, works with a single
/// hand, and keeps the digits off the system keyboard. Submits via [onSubmit]
/// once the confirm key is pressed with 4–6 digits entered; the pad always
/// clears afterwards so a rejected attempt starts fresh.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.onSubmit,
    super.key,
    this.label = 'Ingiza PIN yako',
    this.disabled = false,
  });

  /// Called with the completed PIN. Thrown errors surface as widget errors.
  final Future<void> Function(String pin) onSubmit;

  final String label;

  /// Disables the whole pad (e.g. while verification runs).
  final bool disabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  static const _maxDigits = 6;
  static const _minDigits = 4;

  String _pin = '';
  bool _submitting = false;

  bool get _locked => widget.disabled || _submitting;

  bool get _canSubmit =>
      _pin.length >= _minDigits && _pin.length <= _maxDigits && !_locked;

  void _addDigit(String digit) {
    if (_locked || _pin.length >= _maxDigits) return;
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_locked || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_pin);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _maxDigits; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _Dot(filled: i < _pin.length),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _Keypad(
          locked: _locked,
          canSubmit: _canSubmit,
          onDigit: _addDigit,
          onBackspace: _backspace,
          onSubmit: _submit,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.primary : Colors.transparent,
        border: Border.all(
          color: filled ? colors.primary : colors.outlineVariant,
          width: 1.5,
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.locked,
    required this.canSubmit,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final bool locked;
  final bool canSubmit;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            children: [
              for (var col = 0; col < 3; col++)
                Expanded(
                  child: _Key(
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
              child: _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                locked: locked,
              ),
            ),
            Expanded(
              child: _Key(
                label: '0',
                onTap: () => onDigit('0'),
                locked: locked,
              ),
            ),
            Expanded(
              child: _Key(
                icon: Icons.check,
                emphasized: true,
                onTap: onSubmit,
                locked: !canSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.emphasized = false,
    required this.onTap,
    required this.locked,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final bool emphasized;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = icon != null
        ? Icon(icon, size: 24)
        : Text(
            label!,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          );
    final button = emphasized
        ? FilledButton(
            onPressed: locked ? null : onTap,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            child: child,
          )
        : FilledButton.tonal(
            onPressed: locked ? null : onTap,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: colors.surfaceContainerHigh,
              foregroundColor: colors.onSurface,
              disabledBackgroundColor: colors.surfaceContainerHighest,
              disabledForegroundColor: colors.onSurface.withValues(alpha: 0.4),
            ),
            child: child,
          );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(height: 52, width: double.infinity, child: button),
    );
  }
}
