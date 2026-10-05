import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/reports_controller.dart';
import '../../data/report_providers.dart';
import '../../application/top_products_controller.dart';

class TopProductsPage extends ConsumerStatefulWidget {
  const TopProductsPage({super.key, this.period = ReportPeriod.today});

  final ReportPeriod period;

  @override
  ConsumerState<TopProductsPage> createState() => _TopProductsPageState();
}

class _TopProductsPageState extends ConsumerState<TopProductsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(topProductsControllerProvider.notifier)
          .load(period: widget.period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(topProductsControllerProvider);
    final loc = context.loc;

    ref.listen<TopProductsState>(topProductsControllerProvider, (prev, next) {
      if (next is TopProductsFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsTopProducts)),
      body: WaveBackground(
        child: switch (state) {
          TopProductsLoading() =>
            const Center(child: CircularProgressIndicator()),
          TopProductsFailure(:final message) => Center(
              child: Text(
                message,
                style:
                    TextStyle(color: AppColors.resolveTextSecondary(context)),
              ),
            ),
          TopProductsLoaded(:final products) => RefreshIndicator(
              onRefresh: () => ref
                  .read(topProductsControllerProvider.notifier)
                  .load(period: widget.period),
              child: products.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              loc.reportsNoSalesData,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.resolveTextTertiary(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(
                            product.productName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${_formatQuantity(product.totalQuantity)} ${loc.reportsSoldLabel}',
                            style: TextStyle(
                              color: AppColors.resolveTextSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                          trailing: Text(
                            formatMoney(product.totalRevenue.toDouble()),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
        },
      ),
    );
  }
}

String _formatQuantity(num quantity) => quantity == quantity.truncateToDouble()
    ? quantity.toInt().toString()
    : quantity.toStringAsFixed(2);
