import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/report_filter.dart';
import '../../data/report_providers.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_kpi_card.dart';
import '../widgets/report_trend_chart.dart';

class BusinessOverviewPage extends ConsumerStatefulWidget {
  const BusinessOverviewPage({super.key});

  @override
  ConsumerState<BusinessOverviewPage> createState() =>
      _BusinessOverviewPageState();
}

class _BusinessOverviewPageState extends ConsumerState<BusinessOverviewPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsBusinessOverview)),
      body: WaveBackground(
        child: Column(
          children: [
            ReportFilterBar(
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final key = encodeFilterKey(_filter.toQueryParams());
                  final asyncData = ref.watch(businessOverviewProvider(key));
                  return asyncData.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (data) => RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(businessOverviewProvider(key)),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            loc.reportsBusinessOverview,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.resolveTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ReportKpiCard(
                                  title: loc.reportsSales,
                                  value: formatMoney(
                                      data.sales.currentValue.toDouble()),
                                  changePercent: data.sales.changePercent,
                                  isPositive: data.sales.isUp,
                                  icon: Icons.store,
                                  iconColor: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ReportKpiCard(
                                  title: loc.reportsGrossProfit,
                                  value: formatMoney(
                                      data.grossProfit.currentValue.toDouble()),
                                  changePercent: data.grossProfit.changePercent,
                                  isPositive: data.grossProfit.isUp,
                                  icon: Icons.trending_up,
                                  iconColor: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ReportKpiCard(
                                  title: loc.reportsExpensesLabel,
                                  value: formatMoney(
                                      data.expenses.currentValue.toDouble()),
                                  changePercent: data.expenses.changePercent,
                                  isPositive: data.expenses.isUp,
                                  icon: Icons.receipt_long,
                                  iconColor: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ReportKpiCard(
                                  title: loc.reportsMoneyBalance,
                                  value: formatMoney(data
                                      .moneyBalance.currentValue
                                      .toDouble()),
                                  icon: Icons.account_balance_wallet,
                                  iconColor: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsSalesPerformance,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ReportTrendChart(
                                    dataPoints: data.salesTrend
                                        .map((t) => ReportTrendDataPoint(
                                              label: t.label,
                                              value: t.revenue.toDouble(),
                                            ))
                                        .toList(),
                                    height: 200,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsTopProducts,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (data.topProducts.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'No data',
                                          style: TextStyle(
                                              color:
                                                  AppColors.resolveTextTertiary(
                                                      context)),
                                        ),
                                      ),
                                    )
                                  else
                                    ...data.topProducts
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final product = entry.value;
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${entry.key + 1}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        title: Text(product.productName),
                                        trailing: Text(
                                          formatMoney(
                                              product.totalRevenue.toDouble()),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
