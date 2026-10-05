import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/loc.dart';

import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/report_filter.dart';
import '../../data/report_providers.dart';
import '../widgets/money_flow_card.dart';
import '../widgets/report_filter_bar.dart';

class MoneyReportPage extends ConsumerStatefulWidget {
  const MoneyReportPage({super.key});

  @override
  ConsumerState<MoneyReportPage> createState() => _MoneyReportPageState();
}

class _MoneyReportPageState extends ConsumerState<MoneyReportPage> {
  ReportFilter _filter = const ReportFilter();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsMoneyMovement)),
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
                  final asyncData = ref.watch(moneyMovementProvider(key));
                  return asyncData.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (data) => RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(moneyMovementProvider(key)),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          MoneyFlowCard(
                            startingBalance: data.startingBalance.toDouble(),
                            moneyIn: data.moneyIn.fold(0.0,
                                (sum, item) => sum + item.amount.toDouble()),
                            moneyOut: data.moneyOut.fold(0.0,
                                (sum, item) => sum + item.amount.toDouble()),
                            currentBalance: data.currentBalance.toDouble(),
                            moneyInItems: data.moneyIn
                                .map((i) => MoneyFlowItem(
                                      label: i.label,
                                      amount: i.amount.toDouble(),
                                    ))
                                .toList(),
                            moneyOutItems: data.moneyOut
                                .map((i) => MoneyFlowItem(
                                      label: i.label,
                                      amount: i.amount.toDouble(),
                                    ))
                                .toList(),
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
