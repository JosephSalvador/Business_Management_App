import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/report_filter.dart';
import '../../data/report_providers.dart';
import '../widgets/report_data_table.dart';
import '../widgets/report_filter_bar.dart';
import '../widgets/report_kpi_card.dart';
import '../widgets/report_pie_chart.dart';
import '../widgets/report_trend_chart.dart';

class ExpensesReportPage extends ConsumerStatefulWidget {
  const ExpensesReportPage({super.key});

  @override
  ConsumerState<ExpensesReportPage> createState() => _ExpensesReportPageState();
}

class _ExpensesReportPageState extends ConsumerState<ExpensesReportPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsExpensesOverview)),
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
                  final summaryAsync = ref.watch(expenseSummaryProvider(key));
                  final trendAsync = ref.watch(expenseTrendProvider(key));
                  final paymentAsync = ref.watch(expenseByPaymentProvider(key));

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(expenseSummaryProvider(key));
                      ref.invalidate(expenseTrendProvider(key));
                      ref.invalidate(expenseByPaymentProvider(key));
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
                          data: (summary) => ReportKpiCard(
                            title: loc.reportsTotalExpenses,
                            value: formatMoney(summary.total.toDouble()),
                            icon: Icons.receipt_long,
                            iconColor: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Category breakdown
                        summaryAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (summary) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.reportsCategoryBreakdown,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ReportPieChart(
                                    segments: summary.byCategory
                                        .map((c) => PieChartSegment(
                                              label: c.categoryName ?? 'Other',
                                              value: c.amount.toDouble(),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Trend
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
                                    dataPoints: trend.dataPoints
                                        .map((t) => ReportTrendDataPoint(
                                              label: t.label,
                                              value: t.amount.toDouble(),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // By payment method
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
                                  ReportDataTable(
                                    columns: [
                                      ReportTableColumn(
                                          label: loc.reportsFilterPayment,
                                          flex: 2),
                                      ReportTableColumn(
                                          label: loc.reportsAmount,
                                          flex: 1,
                                          align: TextAlign.right),
                                    ],
                                    rows: payments
                                        .map((p) => ReportTableRow(cells: [
                                              p.paymentMethod,
                                              p.amount.toDouble(),
                                            ]))
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
