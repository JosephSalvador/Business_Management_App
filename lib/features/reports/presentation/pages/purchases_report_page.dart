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

class PurchasesReportPage extends ConsumerStatefulWidget {
  const PurchasesReportPage({super.key});

  @override
  ConsumerState<PurchasesReportPage> createState() =>
      _PurchasesReportPageState();
}

class _PurchasesReportPageState extends ConsumerState<PurchasesReportPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsPurchasesOverview)),
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
                  final summaryAsync = ref.watch(purchasesSummaryProvider(key));
                  final bySupplierAsync =
                      ref.watch(purchasesBySupplierProvider(key));

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(purchasesSummaryProvider(key));
                      ref.invalidate(purchasesBySupplierProvider(key));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        summaryAsync.when(
                          loading: () => const SizedBox(
                              height: 200,
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (summary) => Column(
                            children: [
                              ReportKpiCard(
                                title: loc.reportsTotalPurchased,
                                value: formatMoney(
                                    summary.totalPurchased.toDouble()),
                                icon: Icons.shopping_cart,
                                iconColor: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ReportKpiCard(
                                      title: loc.reportsSuppliers,
                                      value: '${summary.supplierCount}',
                                      icon: Icons.business,
                                      iconColor: AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ReportKpiCard(
                                      title: loc.reportsItemsReceived,
                                      value: '${summary.itemsReceived}',
                                      icon: Icons.inventory,
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
                                      title: loc.reportsPendingOrders,
                                      value: '${summary.pendingCount}',
                                      icon: Icons.pending,
                                      iconColor: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ReportKpiCard(
                                      title: loc.reportsReceivedOrders,
                                      value: '${summary.receivedCount}',
                                      icon: Icons.check_circle,
                                      iconColor: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              if (summary.topSupplierName != null) ...[
                                const SizedBox(height: 12),
                                Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.star,
                                        color: AppColors.warning),
                                    title: Text(loc.reportsTopSupplier),
                                    subtitle: Text(summary.topSupplierName!),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        bySupplierAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (suppliers) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.reportsBySupplier,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReportPieChart(
                                segments: suppliers.items
                                    .map((s) => PieChartSegment(
                                          label: s.supplierName,
                                          value: s.totalAmount.toDouble(),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                              ReportDataTable(
                                columns: [
                                  ReportTableColumn(
                                      label: loc.reportsSuppliers, flex: 3),
                                  ReportTableColumn(
                                      label: 'Orders',
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsAmount,
                                      flex: 2,
                                      align: TextAlign.right),
                                ],
                                rows: suppliers.items
                                    .map((s) => ReportTableRow(cells: [
                                          s.supplierName,
                                          s.orderCount,
                                          s.totalAmount.toDouble(),
                                        ]))
                                    .toList(),
                              ),
                            ],
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
