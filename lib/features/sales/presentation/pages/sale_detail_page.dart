import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/format/money.dart';
import '../../domain/sale.dart';

/// Sale details: totals, lines and payments, with the receipt one tap away.
/// Loads directly through the repository — a tiny read-only screen.
class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  SaleDto? _sale;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale =
          await ref.read(saleRepositoryProvider).getById(widget.saleId);
      if (mounted) {
        setState(() => _sale = sale);
      }
    } on Exception catch (_) {
      // Offline or not yet synced: serve the provisional local copy.
      final local = await ref
          .read(localSalesServiceProvider)
          .findProvisionalDto(widget.saleId);
      if (mounted) {
        setState(() {
          if (local != null) {
            _sale = local;
          } else {
            _error = 'Imeshindikana kupakia risiti. Jaribu tena.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mauzo')),
      floatingActionButton: _sale == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.receipt),
              label: const Text('Risiti'),
              onPressed: () =>
                  context.push(Routes.receipt(_sale!.id)),
            ),
      body: switch ((_sale, _error)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (_, final error?) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(error),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _load, child: const Text('Jaribu tena')),
              ],
            ),
          ),
        (final sale?, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(sale.number,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(_formatDate(sale.saleDate.toLocal())),
              const Divider(height: 24),
              for (final line in sale.lines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.productName),
                  subtitle: Text(
                    '${line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2)} x '
                    '${formatMoney(line.unitPrice)}',
                  ),
                  trailing: Text(formatMoney(line.lineTotal - line.discountAmount)),
                ),
              const Divider(),
              _SummaryRow(label: 'Jumla ndogo', value: sale.subtotal),
              _SummaryRow(label: 'Kodi (VAT)', value: sale.taxAmount),
              if (sale.discountAmount > 0)
                _SummaryRow(label: 'Punguzo', value: -sale.discountAmount),
              _SummaryRow(label: 'JUMLA', value: sale.totalAmount, bold: true),
              const Divider(),
              for (final payment in sale.payments)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payment_outlined),
                  title: Text(payment.label),
                  trailing: Text(formatMoney(payment.amount)),
                ),
            ],
          ),
      },
    );
  }

  String _formatDate(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(formatMoney(value), style: style)],
      ),
    );
  }
}
