import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/format/money.dart';
import '../../application/checkout_controller.dart';
import '../../domain/sale.dart';

/// Opens the payment flow as a modal sheet over the POS screen.
Future<void> showPaymentSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PaymentSheet(),
  );
  // Leaving the flow (success or failure) closes the logical sale window.
  if (ref.read(checkoutControllerProvider) is! CheckoutSubmitting) {
    ref.read(checkoutControllerProvider.notifier).reset();
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet();

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  int _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    ref.listenManual<CheckoutState>(
      checkoutControllerProvider,
      _onCheckoutStateChanged,
    );
  }

  void _onCheckoutStateChanged(CheckoutState? previous, CheckoutState next) {
    if (next is CheckoutSuccess && mounted) {
      ref.read(cartControllerProvider.notifier).clear();
      ref.read(salesHistoryControllerProvider.notifier).loadToday();
      Navigator.of(context).pop();
      context.pushReplacement(Routes.posSuccess, extra: next.sale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider);
    final submitting = checkout is CheckoutSubmitting;
    final failure = checkout is CheckoutFailure ? checkout.message : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jumla', style: Theme.of(context).textTheme.titleMedium),
            Text(
              formatMoney(cart.total),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            Text('Njia ya malipo:',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MethodButton(
                    label: 'Cash',
                    icon: Icons.payments_outlined,
                    selected: _method == PaymentMethod.cash,
                    onTap: () =>
                        setState(() => _method = PaymentMethod.cash),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodButton(
                    label: 'Mobile Money',
                    icon: Icons.smartphone,
                    selected: _method == PaymentMethod.mobileMoney,
                    onTap: () =>
                        setState(() => _method = PaymentMethod.mobileMoney),
                  ),
                ),
              ],
            ),
            if (failure != null) ...[
              const SizedBox(height: 12),
              Text(
                failure,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  submitting || cart.isEmpty ? null : () => _submit(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lipa', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final lines = ref.read(cartControllerProvider).lines;
    await ref.read(checkoutControllerProvider.notifier).submit(
          lines: lines,
          paymentMethod: _method,
        );
    // Success/failure rendering is handled by the state listener above.
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor:
            selected ? theme.colorScheme.primaryContainer : null,
        side: BorderSide(
          width: selected ? 2 : 1,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
