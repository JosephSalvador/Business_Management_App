import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../application/stock_controller.dart';

/// The Stock tab: on-hand quantity per product. Warehouse detail is hidden —
/// users see "Stock", not stock locations.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(stockControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: switch (state) {
        StockLoading() => const Center(child: CircularProgressIndicator()),
        StockFailure(:final message) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(stockControllerProvider.notifier).load(),
                  child: const Text('Jaribu tena'),
                ),
              ],
            ),
          ),
        StockEmpty() => const Center(
            child: Text('Hakuna stock bado. Anza kwa kuongeza bidhaa.'),
          ),
        StockReady() => RefreshIndicator(
            onRefresh: () =>
                ref.read(stockControllerProvider.notifier).load(),
            child: ListView.separated(
              itemCount: state.lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = state.lines[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(line.product.name),
                  subtitle: Text(line.warehouseName),
                  trailing: Text(
                    _format(line.quantity),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                );
              },
            ),
          ),
      },
    );
  }

  static String _format(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
