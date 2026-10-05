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
import '../widgets/report_pie_chart.dart';
import '../widgets/report_trend_chart.dart';

class SalesReportPage extends ConsumerStatefulWidget {
  const SalesReportPage({super.key});

  @override
  ConsumerState<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends ConsumerState<SalesReportPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsSalesPerformance)),
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
                  final summaryAsync = ref.watch(salesSummaryProvider(key));
                  final paymentAsync = ref.watch(salesByPaymentProvider(key));
                  final categoryAsync = ref.watch(salesByCategoryProvider(key));
                  final trendAsync = ref.watch(salesTrendProvider(
                      encodeFilterKey(
                          {'days': 30, ..._filter.toQueryParams()})));

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(salesSummaryProvider(key));
                      ref.invalidate(salesByPaymentProvider(key));
                      ref.invalidate(salesByCategoryProvider(key));
                      ref.invalidate(salesTrendProvider(encodeFilterKey(
                          {'days': 30, ..._filter.toQueryParams()})));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        summaryAsync.when(
                          loading: () => const SizedBox(
                              height: 120,
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (summary) => Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ReportKpiCard(
                                      title: loc.reportsSales,
                                      value: formatMoney(
                                          summary.totalRevenue.toDouble()),
                                      icon: Icons.store,
                                      iconColor: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ReportKpiCard(
                                      title: loc.reportsAverageSale,
                                      value: formatMoney(
                                          summary.averageSale.toDouble()),
                                      icon: Icons.receipt,
                                      iconColor: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ReportKpiCard(
                                title: loc.reportsSaleCount,
                                value: '${summary.totalSales}',
                                icon: Icons.shopping_cart,
                                iconColor: AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        trendAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (trend) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsTrend,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ReportTrendChart(
                                    dataPoints: trend
                                        .map((t) => ReportTrendDataPoint(
                                              label: t.label,
                                              value: t.revenue.toDouble(),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        paymentAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (payments) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsByPaymentMethod,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ReportPieChart(
                                    segments: payments
                                        .map((p) => PieChartSegment(
                                              label: p.paymentMethod,
                                              value: p.amount.toDouble(),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        categoryAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (categories) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsByCategory,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ReportPieChart(
                                    segments: categories
                                        .map((c) => PieChartSegment(
                                              label: c.categoryName,
                                              value: c.amount.toDouble(),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
