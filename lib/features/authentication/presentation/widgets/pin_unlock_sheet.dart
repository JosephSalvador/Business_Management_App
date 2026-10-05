import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';

/// Modal bottom sheet for entering (verify) or choosing (setup) the 4–6 digit
/// device unlock PIN — the fast factor on devices without a biometric sensor.
///
/// Returns `true` after [onSubmit] completes successfully; the sheet stays
/// open on failure (e.g. a [ValidationException] from the lockout path) so the
/// user can retry. Returns `false` when dismissed.
Future<bool> showPinUnlockSheet(
  BuildContext context, {
  required bool setup,
  required Future<void> Function(String pin) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _PinUnlockSheet(
      setup: setup,
      onSubmit: onSubmit,
    ),
  ).then((value) => value ?? false);
}

class _PinUnlockSheet extends StatefulWidget {
  const _PinUnlockSheet({required this.setup, required this.onSubmit});

  final bool setup;
  final Future<void> Function(String pin) onSubmit;

  @override
  State<_PinUnlockSheet> createState() => _PinUnlockSheetState();
}

class _PinUnlockSheetState extends State<_PinUnlockSheet> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final loc = context.loc;
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = loc.pinLengthError);
      return;
    }
    if (widget.setup && pin != _confirmController.text.trim()) {
      setState(() => _error = loc.pinMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(pin);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = loc.commonRetry;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.viewInsetsOf(context) == EdgeInsets.zero ? 24 : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.pin_outlined,
                size: 30,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.setup ? loc.pinSetupTitle : loc.pinUnlockTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.setup ? loc.pinSetupHint : loc.pinHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textInputAction:
                widget.setup ? TextInputAction.next : TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => widget.setup ? null : _submit(),
            decoration: InputDecoration(
              labelText: loc.pinLabel,
              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.setup) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: loc.pinRepeat,
                prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.setup ? loc.pinSave : loc.pinUnlock),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(loc.commonCancel),
          ),
        ],
      ),
    );
  }
}
