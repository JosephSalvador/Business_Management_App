import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';
import 'pin_pad.dart';

/// The M-Pesa-style fast security prompt: a large fingerprint button and/or an
/// inline PIN pad, shared by the login and lock screens.
class FastUnlockPanel extends StatelessWidget {
  const FastUnlockPanel({
    required this.biometricAvailable,
    required this.showPinPad,
    required this.onFingerprint,
    required this.onPin,
    super.key,
    this.busy = false,
    this.errorMessage,
  });

  final bool biometricAvailable;
  final bool showPinPad;
  final bool busy;
  final String? errorMessage;
  final Future<void> Function() onFingerprint;
  final Future<void> Function(String pin) onPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (biometricAvailable) ...[
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => onFingerprint(),
            icon: const Icon(Icons.fingerprint, size: 44),
            label: Text(
              busy ? 'Inathibitisha…' : 'Fungua kwa Kidole',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(68),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tumia alama ya vidole au uso',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.resolveTextSecondary(context),
              fontSize: 11,
            ),
          ),
        ],
        if (biometricAvailable && showPinPad) ...[
          const SizedBox(height: 14),
          Text(
            'au ingiza PIN yako',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.resolveTextSecondary(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (showPinPad)
          PinPad(
            label: biometricAvailable ? '' : 'Ingiza PIN yako',
            disabled: busy,
            onSubmit: onPin,
          ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
