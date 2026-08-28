import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/format/money.dart';
import '../../application/sales_history_controller.dart';
import '../../domain/sale.dart';

/// "Mauzo ya leo" — the day's sales with receipt number, time, total and
/// payment method. Tapping a sale opens its details.
class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(salesHistoryControllerProvider.notifier).loadToday(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mauzo ya leo')),
      body: switch (state) {
        SalesHistoryLoading() =>
          const Center(child: CircularProgressIndicator()),
        SalesHistoryFailure(:final message) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(salesHistoryControllerProvider.notifier)
                      .loadToday(),
                  child: const Text('Jaribu tena'),
                ),
              ],
            ),
          ),
        SalesHistoryLoaded() when state.isEmpty => const Center(
            child: Text('Hakuna mauzo leo bado.'),
          ),
        SalesHistoryLoaded() => RefreshIndicator(
            onRefresh: () => ref
                .read(salesHistoryControllerProvider.notifier)
                .loadToday(),
            child: ListView.separated(
              itemCount: state.sales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _SaleTile(sale: state.sales[index]),
            ),
          ),
      },
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final SaleDto sale;

  @override
  Widget build(BuildContext context) {
    final time = sale.saleDate.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return ListTile(
      leading: sale.isVoided
          ? Icon(Icons.cancel_outlined,
              color: Theme.of(context).colorScheme.error)
          : const Icon(Icons.receipt_outlined),
      title: Text(
        sale.number.isEmpty ? '(risiti)' : sale.number,
        style: TextStyle(
          decoration: sale.isVoided ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('${two(time.hour)}:${two(time.minute)} · '
          '${sale.payments.isEmpty ? '' : sale.payments.first.label}'),
      trailing: Text(
        formatMoney(sale.totalAmount),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      onTap: () => context.push(Routes.saleDetail(sale.id)),
    );
  }
}
