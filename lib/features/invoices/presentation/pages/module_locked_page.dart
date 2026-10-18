import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../billing/domain/billing.dart';

class ModuleLockedPage extends ConsumerWidget {
  const ModuleLockedPage({super.key});

  Future<void> _openQuickVoucherDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _QuickVoucherDialog(parentRef: ref),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final auth = ref.watch(authControllerProvider);
    final canManageBilling = auth is AuthAuthenticated &&
        auth.session.user.hasPermission('Billing.Manage');

    return Scaffold(
      appBar: AppBar(title: Text(loc.moduleLockedTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.moduleLockedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                loc.moduleLockedMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.resolveTextSecondary(context),
                    ),
              ),
              const SizedBox(height: 24),
              if (canManageBilling) ...[
                FilledButton.icon(
                  onPressed: () => _openQuickVoucherDialog(context, ref),
                  icon: const Icon(Icons.confirmation_num_outlined, size: 18),
                  label: const Text('Weka Vocha ya Kuwezesha'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go(Routes.billing),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(loc.moduleLockedGoToBilling),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.home),
                child: Text(loc.moduleLockedBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickVoucherDialog extends StatefulWidget {
  const _QuickVoucherDialog({required this.parentRef});

  final WidgetRef parentRef;

  @override
  State<_QuickVoucherDialog> createState() => _QuickVoucherDialogState();
}

class _QuickVoucherDialogState extends State<_QuickVoucherDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        setState(() {
          _controller.text = VoucherCode.normalize(text);
          _error = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.parentRef
          .read(billingControllerProvider.notifier)
          .redeemVoucher(code);
      await widget.parentRef.read(capabilitiesStateProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kifurushi kimewezeshwa mara moja!')),
      );

      if (context.canPop()) {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Vocha haijatambuliwa au imekwishatumika.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.confirmation_num_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Weka Vocha ya Kufungua'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weka nambari ya vocha uliyopokea baada ya kulipia ili ufungue huduma hii mara moja.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'JLX-XXXX-XXXX',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_rounded),
                tooltip: 'Bandika',
                onPressed: _isLoading ? null : _paste,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Ghairi'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _redeem,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Wezesha Sasa'),
        ),
      ],
    );
  }
}
