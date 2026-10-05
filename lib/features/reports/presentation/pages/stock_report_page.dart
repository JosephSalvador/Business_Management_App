import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/report_filter.dart';
import '../../data/report_providers.dart';
import '../widgets/report_data_table.dart';
import '../widgets/report_filter_bar.dart';

class StockReportPage extends ConsumerStatefulWidget {
  const StockReportPage({super.key});

  @override
  ConsumerState<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends ConsumerState<StockReportPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsStockOverview)),
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
                  final summaryAsync = ref.watch(stockSummaryProvider(key));
                  final movementAsync =
                      ref.watch(stockMovementSummaryProvider(key));
                  final velocityAsync = ref.watch(stockVelocityProvider(key));

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(stockSummaryProvider(key));
                      ref.invalidate(stockMovementSummaryProvider(key));
                      ref.invalidate(stockVelocityProvider(key));
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.reportsStockSummary,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReportDataTable(
                                columns: [
                                  ReportTableColumn(
                                      label: loc.reportsProduct, flex: 3),
                                  ReportTableColumn(
                                      label: loc.reportsOpening,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsPurchased,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsSold,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsClosing,
                                      flex: 1,
                                      align: TextAlign.right),
                                ],
                                rows: summary.rows
                                    .map((r) => ReportTableRow(cells: [
                                          r.productName,
                                          r.opening.toDouble(),
                                          r.purchased.toDouble(),
                                          r.sold.toDouble(),
                                          r.closing.toDouble(),
                                        ]))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        movementAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (movements) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.reportsStockVelocity,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReportDataTable(
                                columns: [
                                  ReportTableColumn(
                                      label: loc.reportsMovementType, flex: 2),
                                  ReportTableColumn(
                                      label: loc.reportsMovementCount,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsTotalQuantity,
                                      flex: 1,
                                      align: TextAlign.right),
                                ],
                                rows: movements.items
                                    .map((m) => ReportTableRow(cells: [
                                          m.movementType,
                                          m.count,
                                          m.totalQuantity.toDouble(),
                                        ]))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        velocityAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (velocity) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.reportsStockVelocity,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ReportDataTable(
                                columns: [
                                  ReportTableColumn(
                                      label: loc.reportsProduct, flex: 3),
                                  ReportTableColumn(
                                      label: loc.reportsSold,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsOnHand,
                                      flex: 1,
                                      align: TextAlign.right),
                                  ReportTableColumn(
                                      label: loc.reportsVelocityPerDay,
                                      flex: 1,
                                      align: TextAlign.right),
                                ],
                                rows: velocity.items
                                    .map((v) => ReportTableRow(cells: [
                                          v.productName,
                                          v.sold.toDouble(),
                                          v.onHand.toDouble(),
                                          v.velocityPerDay.toDouble(),
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
