import 'package:flutter/material.dart';

import 'pin_pad.dart';

/// Clean, professional fast security prompt:
/// - Sleek 4-dot PIN entry pad.
/// - Integrated biometric key on the numeric pad when available.
/// - Error presentation.
class FastUnlockPanel extends StatelessWidget {
  const FastUnlockPanel({
    required this.biometricAvailable,
    required this.showPinPad,
    required this.onFingerprint,
    required this.onPin,
    super.key,
    this.busy = false,
    this.errorMessage,
    this.label = 'Ingiza PIN yako',
  });

  final bool biometricAvailable;
  final bool showPinPad;
  final bool busy;
  final String? errorMessage;
  final String label;
  final Future<void> Function() onFingerprint;
  final Future<void> Function(String pin) onPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPinPad)
          PinPad(
            label: label,
            disabled: busy,
            digitsCount: 4,
            onSubmit: onPin,
            onBiometric: biometricAvailable ? onFingerprint : null,
          ),
        if (errorMessage != null && errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
