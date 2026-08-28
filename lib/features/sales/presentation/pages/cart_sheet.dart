import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../shared/format/money.dart';
import 'payment_sheet.dart';

/// The cart review sheet: adjust quantities, remove items, continue to pay.
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kikapu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.lines.length,
                itemBuilder: (context, index) {
                  final line = cart.lines[index];
                  return Row(
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
                        tooltip: 'Punguza',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => ref
                            .read(cartControllerProvider.notifier)
                            .decrement(line.productId),
                      ),
                      Text(
                        line.quantity.toStringAsFixed(
                            line.quantity % 1 == 0 ? 0 : 2),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Ongeza',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => ref
                            .read(cartControllerProvider.notifier)
                            .increment(line.productId),
                      ),
                      IconButton(
                        tooltip: 'Ondoa',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(cartControllerProvider.notifier)
                            .remove(line.productId),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jumla',
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
            const Text(
              'Bei zinajumuisha kodi.',
              style: TextStyle(fontSize: 12),
            ),
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
              child: const Text('Endelea na malipo',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
