import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_routes.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';

final purchaseDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final client = ref.read(apiClientProvider);
  final result = await client.get<dynamic>(
    ApiRoutes.v1('/purchase-orders/$id'),
  );
  return Map<String, dynamic>.from(result.data as Map);
});

class PurchaseDetailPage extends ConsumerWidget {
  const PurchaseDetailPage({super.key, required this.purchaseId});

  final String purchaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseDetailProvider(purchaseId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.purchasesDetailTitle),
      ),
      body: WaveBackground(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text(context.loc.purchasesDetailNotFound)),
          data: (purchase) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, purchase),
                const SizedBox(height: 16),
                _buildInfoCard(context, purchase),
                const SizedBox(height: 16),
                _buildLines(context, purchase),
                const SizedBox(height: 16),
                _buildTotal(context, purchase),
                const SizedBox(height: 24),
                _buildActions(context, ref, purchase),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> purchase) {
    final ref = purchase['reference'] ?? '';
    final status = purchase['status'] ?? '';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.isNotEmpty ? ref : context.loc.purchasesOrderLabel,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                purchase['supplierName'] ?? '',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA502).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Color(0xFFFFA502),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, Map<String, dynamic> purchase) {
    final dateStr = purchase['orderDate'] ?? '';
    final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(context.loc.purchasesDetailDate,
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '-'),
            const Divider(),
            _infoRow(context.loc.purchasesDetailOffice,
                purchase['warehouseName'] ?? '-'),
            const Divider(),
            _infoRow(context.loc.purchasesNotes, purchase['notes'] ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLines(BuildContext context, Map<String, dynamic> purchase) {
    final lines = purchase['lines'] as List<dynamic>? ?? [];
    if (lines.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.purchasesDetailProducts,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line['productName'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${line['quantity']} x ${formatMoney((line['unitPrice'] ?? 0).toDouble())}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatMoney((line['lineTotal'] ?? 0).toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTotal(BuildContext context, Map<String, dynamic> purchase) {
    final total = (purchase['totalAmount'] ?? 0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.loc.commonTotal,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
              formatMoney(total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0066FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, WidgetRef ref, Map<String, dynamic> purchase) {
    final status = purchase['status'] ?? '';
    if (status != 'Draft') return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _submit(context, ref),
            child: Text(context.loc.purchasesSubmit),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.loc.commonCancel),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(purchasesControllerProvider.notifier).submit(purchaseId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.purchasesSubmitted)),
        );
        ref.invalidate(purchaseDetailProvider(purchaseId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError(e.toString()))),
        );
      }
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(purchasesControllerProvider.notifier).cancel(purchaseId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.purchasesCancelled)),
        );
        ref.invalidate(purchaseDetailProvider(purchaseId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError(e.toString()))),
        );
      }
    }
  }
}
