import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/invoices_controller.dart';
import '../../domain/invoice.dart';
import 'invoices_page.dart' show invoiceStatusColor, invoiceStatusLabel;

class InvoiceDetailPage extends ConsumerStatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  CustomerInvoice? _invoice;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invoice = await ref
        .read(invoicesControllerProvider.notifier)
        .getById(widget.invoiceId);
    if (!mounted) return;
    final loc = context.loc;
    setState(() {
      _invoice = invoice;
      _error = invoice == null ? loc.commonError : null;
    });
  }

  Future<void> _run(Future<CustomerInvoice?> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    final invoice = await action();
    if (!mounted) return;
    final state = ref.read(invoicesControllerProvider);
    setState(() {
      _working = false;
      if (invoice != null) {
        _invoice = invoice;
        _error = null;
      } else if (state is InvoicesFailure) {
        _error = state.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? loc.invoiceDetailTitle
              : '${loc.invoiceDetailTitle} ${invoice.number}',
        ),
      ),
      body: WaveBackground(
        child: invoice == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(
                        _error!,
                        style: TextStyle(
                            color: AppColors.resolveTextSecondary(context)),
                      ),
              )
            : _buildInvoice(context, invoice, loc),
      ),
    );
  }

  Widget _buildInvoice(
    BuildContext context,
    CustomerInvoice invoice,
    AppLocalizations loc,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.number,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      invoiceStatusLabel(context, invoice.status),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: invoiceStatusColor(context, invoice.status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.customerId == null
                      ? loc.invoiceWalkIn
                      : invoice.customerLabel,
                  style:
                      TextStyle(color: AppColors.resolveTextSecondary(context)),
                ),
                if (invoice.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${loc.invoiceDueDate}: ${_date(invoice.dueDate!)}',
                    style: TextStyle(
                      color: invoice.isOverdue ? AppColors.error : null,
                      fontSize: 13,
                    ),
                  ),
                ],
                const Divider(height: 24),
                for (final line in invoice.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.description} × ${formatPriceValue(line.quantity)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(formatPriceValue(line.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: 16),
                _SummaryRow(
                  label: loc.invoiceTotal,
                  value: formatMoney(invoice.totalAmount, alwaysDecimals: true),
                  bold: true,
                ),
                if (invoice.amountPaid > 0)
                  _SummaryRow(
                    label: loc.invoicePaymentAmount,
                    value:
                        formatMoney(invoice.amountPaid, alwaysDecimals: true),
                  ),
                if (invoice.status.isOpen)
                  _SummaryRow(
                    label: loc.invoiceBalance,
                    value:
                        formatMoney(invoice.balanceDue, alwaysDecimals: true),
                    bold: true,
                  ),
                if (invoice.paymentMethod != null ||
                    invoice.paymentReference != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        if (invoice.paymentMethod != null)
                          '${loc.invoicePaymentMethod}: ${invoice.paymentMethod}',
                        if (invoice.paymentReference != null)
                          '${loc.invoicePaymentReference}: ${invoice.paymentReference}',
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ),
                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(invoice.notes!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (invoice.canTakePayment)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _working
                      ? null
                      : () => _showPaymentSheet(context, invoice),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(loc.invoiceRecordPayment),
                ),
              ),
            if (invoice.canTakePayment && invoice.canVoid)
              const SizedBox(width: 12),
            if (invoice.canVoid)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _working ? null : () => _confirmVoid(invoice),
                  icon: const Icon(Icons.block_outlined),
                  label: Text(loc.invoiceVoid),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPaymentSheet(
    BuildContext context,
    CustomerInvoice invoice,
  ) async {
    final amountController =
        TextEditingController(text: invoice.balanceDue.toStringAsFixed(2));
    final methodController = TextEditingController();
    final referenceController = TextEditingController();
    final loc = context.loc;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.invoiceRecordPayment,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.invoicePaymentAmount,
                    helperText:
                        '${loc.invoiceBalance}: ${formatMoney(invoice.balanceDue)}',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: methodController,
                  decoration:
                      InputDecoration(labelText: loc.invoicePaymentMethod),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration:
                      InputDecoration(labelText: loc.invoicePaymentReference),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) return;
                    final method = _orNull(methodController.text);
                    final reference = _orNull(referenceController.text);
                    Navigator.of(sheetContext).pop();
                    await _run(
                      () => ref
                          .read(invoicesControllerProvider.notifier)
                          .recordPayment(
                            invoice.id,
                            amount: amount,
                            method: method,
                            reference: reference,
                          ),
                    );
                  },
                  child: Text(loc.invoiceRecordPayment),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      amountController.dispose();
      methodController.dispose();
      referenceController.dispose();
    }
  }

  Future<void> _confirmVoid(CustomerInvoice invoice) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.invoiceVoid),
        content: Text(loc.invoiceVoidConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.invoiceVoid),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () =>
          ref.read(invoicesControllerProvider.notifier).voidInvoice(invoice.id),
    );
  }

  static String? _orNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      fontSize: bold ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
