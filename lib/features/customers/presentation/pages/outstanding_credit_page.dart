import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../pages/record_payment_page.dart';

final _outstandingCreditFutureProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(customersControllerProvider.notifier).getOutstandingCredit();
});

class OutstandingCreditPage extends ConsumerWidget {
  const OutstandingCreditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOutstanding = ref.watch(_outstandingCreditFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.outstandingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_outstandingCreditFutureProvider),
          ),
        ],
      ),
      body: WaveBackground(
        child: asyncOutstanding.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(context.loc.commonWithError(e.toString())),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(_outstandingCreditFutureProvider),
                  child: Text(context.loc.commonRetry),
                ),
              ],
            ),
          ),
          data: (outstanding) {
            if (outstanding.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 64, color: Color(0xFF16A34A)),
                    const SizedBox(height: 16),
                    Text(
                      context.loc.outstandingEmpty,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            final totalOutstanding = outstanding.fold<double>(
              0,
              (sum, c) => sum + (c['balance'] as num? ?? 0).toDouble(),
            );

            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: const Color(0xFFFDF2F2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.loc.outstandingTotal,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'TSh ${totalOutstanding.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: outstanding.length,
                    itemBuilder: (context, index) {
                      final credit = outstanding[index];
                      final customerId = credit['customerId'] ?? '';
                      final balance =
                          (credit['balance'] as num? ?? 0).toDouble();
                      final lastPayment = credit['lastPaymentAt'] as String?;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFFDC2626).withAlpha(25),
                            child: const Icon(Icons.person,
                                color: Color(0xFFDC2626)),
                          ),
                          title: Text(
                            context.loc.outstandingCustomer(
                                customerId.substring(0, 8)),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: lastPayment != null
                              ? Text(
                                  context.loc.outstandingLastPayment(
                                      lastPayment.substring(0, 10)),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                )
                              : null,
                          trailing: Text(
                            'TSh ${balance.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordPaymentPage(
                                  customerId: customerId,
                                  customerName: context.loc.outstandingCustomer(
                                      customerId.substring(0, 8)),
                                  balance: balance,
                                ),
                              ),
                            );
                            if (result == true) {
                              ref.invalidate(_outstandingCreditFutureProvider);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
