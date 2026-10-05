import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../domain/sale.dart';
import 'payment_sheet.dart';

/// The cart review sheet: adjust quantities (tap the number to type an exact
/// amount), remove items, continue to pay. Supports decimal quantities for
/// weigh-and-sell lines.
Future<void> showCartSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CartSheet(),
  );
}

class _CartSheet extends ConsumerWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final loc = context.loc;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loc.posCart, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.lines.length,
                itemBuilder: (context, index) {
                  final line = cart.lines[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(formatMoney(line.lineTotal)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: loc.posDecrease,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => ref
                              .read(cartControllerProvider.notifier)
                              .decrement(line.key),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _editQuantity(context, ref, line),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Text(
                              _formatQuantity(line.quantity),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: loc.posIncrease,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => ref
                              .read(cartControllerProvider.notifier)
                              .increment(line.key),
                        ),
                        IconButton(
                          tooltip: loc.posRemove,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(cartControllerProvider.notifier)
                              .remove(line.key),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.posCartTotal,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  formatMoney(cart.total),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: cart.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      showPaymentSheet(context, ref);
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(loc.posContinueToPayment,
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantity(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final controller =
        TextEditingController(text: _formatQuantity(line.quantity));
    final loc = context.loc;
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.posSetQuantity),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: loc.posQuantity,
            hintText: line.name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(loc.commonDone),
          ),
        ],
      ),
    );
    if (value != null) {
      ref.read(cartControllerProvider.notifier).setQuantity(line.key, value);
    }
  }
}

String _formatQuantity(double quantity) => quantity % 1 == 0
    ? quantity.round().toString()
    : quantity.toStringAsFixed(2);
