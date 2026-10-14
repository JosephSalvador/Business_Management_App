import 'package:flutter/material.dart';

import '../../../../core/network/app_exception.dart';
import 'pin_pad.dart';

/// Modal bottom sheet for setting up or updating a 4-digit Quick PIN.
/// Includes an optional toggle to enable biometric authentication on supported devices.
Future<bool> showQuickPinSetupSheet(
  BuildContext context, {
  required bool biometricSupported,
  required Future<void> Function({
    required String pin,
    required bool enableBiometric,
  }) onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _QuickPinSetupSheet(
      biometricSupported: biometricSupported,
      onSave: onSave,
    ),
  ).then((value) => value ?? false);
}

class _QuickPinSetupSheet extends StatefulWidget {
  const _QuickPinSetupSheet({
    required this.biometricSupported,
    required this.onSave,
  });

  final bool biometricSupported;
  final Future<void> Function({
    required String pin,
    required bool enableBiometric,
  }) onSave;

  @override
  State<_QuickPinSetupSheet> createState() => _QuickPinSetupSheetState();
}

class _QuickPinSetupSheetState extends State<_QuickPinSetupSheet> {
  int _step = 1; // 1 = enter pin, 2 = confirm pin
  String _firstPin = '';
  bool _enableBiometric = true;
  bool _busy = false;
  String? _error;

  void _onStepOneComplete(String pin) {
    setState(() {
      _firstPin = pin;
      _step = 2;
      _error = null;
    });
  }

  Future<void> _onStepTwoComplete(String confirmPin) async {
    if (confirmPin != _firstPin) {
      setState(() {
        _error = 'PIN hazifanani. Jaribu tena kuanzia mwanzo.';
        _step = 1;
        _firstPin = '';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSave(
        pin: _firstPin,
        enableBiometric: widget.biometricSupported && _enableBiometric,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
          _step = 1;
          _firstPin = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Hitilafu imetokea. Tafadhali jaribu tena.';
          _step = 1;
          _firstPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStepTwo = _step == 2;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context) == EdgeInsets.zero ? 24 : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isStepTwo ? 'Thibitisha PIN yako' : 'Weka PIN ya Haraka',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isStepTwo
                          ? 'Ingiza tena tarakimu 4 zile zile'
                          : 'Tarakimu 4 kwa ajili ya kufungua haraka',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          PinPad(
            key: ValueKey(_step),
            label: isStepTwo ? 'Rudia PIN yako' : 'Chagua PIN ya tarakimu 4',
            digitsCount: 4,
            disabled: _busy,
            onSubmit: (pin) async {
              if (isStepTwo) {
                await _onStepTwoComplete(pin);
              } else {
                _onStepOneComplete(pin);
              }
            },
          ),
          if (widget.biometricSupported && !isStepTwo) ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _enableBiometric,
              onChanged: _busy ? null : (v) => setState(() => _enableBiometric = v),
              title: const Text('Ruhusu pia alama ya kidole au uso'),
              subtitle: const Text('Kufungua app kwa haraka zaidi'),
              secondary: Icon(
                Icons.fingerprint,
                color: theme.colorScheme.primary,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Ruka kwa sasa (Tumia nenosiri tu)'),
          ),
        ],
      ),
    );
  }
}
