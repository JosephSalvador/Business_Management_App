import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../data/purchase_providers.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';

final purchaseDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.read(purchaseRepositoryProvider).getById(id);
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
        actions: [
          if (detailAsync.asData?.value['status']?.toString() == '0' ||
              detailAsync.asData?.value['status']?.toString().toLowerCase() ==
                  'draft')
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Draft',
              onPressed: () => context.push('/purchases/$purchaseId/edit'),
            ),
        ],
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
    final reference = purchase['reference']?.toString() ?? '';
    final status = _statusLabel(purchase['status']);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reference.isNotEmpty
                    ? reference
                    : context.loc.purchasesOrderLabel,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                purchase['supplierName']?.toString() ??
                    purchase['supplierId']?.toString() ??
                    '',
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
    final dateStr = purchase['orderDate']?.toString() ?? '';
    final date =
        dateStr.isNotEmpty ? DateTime.tryParse(dateStr)?.toLocal() : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(context.loc.purchasesDetailDate,
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '-'),
            const Divider(),
            _infoRow(
                context.loc.purchasesDetailOffice,
                purchase['warehouseName']?.toString() ??
                    purchase['warehouseId']?.toString() ??
                    '-'),
            const Divider(),
            _infoRow(context.loc.purchasesNotes,
                purchase['notes']?.toString() ?? '-'),
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
    final lines =
        (purchase['lines'] ?? purchase['items'] ?? const []) as List<dynamic>;
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
            ...lines.whereType<Map<dynamic, dynamic>>().map((rawLine) {
              final line = Map<String, dynamic>.from(rawLine);
              final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
              final unitPrice = (line['unitPrice'] as num?)?.toDouble() ?? 0;
              final lineTotal = (line['lineTotal'] as num?)?.toDouble() ??
                  quantity * unitPrice;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line['productName']?.toString() ??
                                line['productId']?.toString() ??
                                '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$quantity x ${formatMoney(unitPrice)}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(lineTotal),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotal(BuildContext context, Map<String, dynamic> purchase) {
    final total =
        (purchase['totalAmount'] as num?)?.toDouble() ?? _lineTotal(purchase);
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
    final status = _statusLabel(purchase['status']);
    if (purchase['isOfflinePending'] == true) {
      return const SizedBox.shrink();
    }

    if (status == 'Submitted') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _receive(context, ref),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Receive Purchase'),
        ),
      );
    }

    if (status != 'Draft') {
      return const SizedBox.shrink();
    }

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

  String _statusLabel(dynamic value) {
    final raw = value?.toString().toLowerCase() ?? '';
    return switch (raw) {
      '0' || 'draft' => 'Draft',
      '1' || 'submitted' => 'Submitted',
      '2' || 'received' => 'Received',
      '3' || 'cancelled' => 'Cancelled',
      _ => value?.toString() ?? '-',
    };
  }

  double _lineTotal(Map<String, dynamic> purchase) {
    final lines =
        (purchase['lines'] ?? purchase['items'] ?? const []) as List<dynamic>;
    return lines.whereType<Map<dynamic, dynamic>>().fold<double>(
          0,
          (total, rawLine) =>
              total +
              ((rawLine['quantity'] as num?)?.toDouble() ?? 0) *
                  ((rawLine['unitPrice'] as num?)?.toDouble() ?? 0),
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

  Future<void> _receive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(purchasesControllerProvider.notifier).receive(purchaseId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase received and stock updated.')),
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
