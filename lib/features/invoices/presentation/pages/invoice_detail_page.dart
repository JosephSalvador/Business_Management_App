import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/invoices_controller.dart';
import '../../data/invoice_providers.dart';
import '../../domain/invoice.dart';
import '../services/customer_invoice_pdf_service.dart';
import '../widgets/invoice_a4_preview_card.dart';
import '../widgets/invoice_branding_sheet.dart';
import '../widgets/preview_frame/preview_frame.dart';
import 'invoice_preview_screen.dart';

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
  bool _sharingPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(settingsControllerProvider.notifier).load();
      _load();
    });
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

  Organization _resolveOrganization() {
    final settingsState = ref.watch(settingsControllerProvider);
    if (settingsState is SettingsLoaded) {
      return settingsState.organization;
    }
    return const Organization(
      id: 'local',
      name: 'Your Business',
      currency: 'TZS',
    );
  }

  Future<void> _shareA4Pdf(
    CustomerInvoice invoice,
    Organization organization,
    bool isSwahili,
  ) async {
    if (_sharingPdf) return;
    setState(() => _sharingPdf = true);
    try {
      await ref.read(customerInvoicePdfServiceProvider).shareA4Pdf(
            invoice: invoice,
            organization: organization,
            isSwahili: isSwahili,
          );
    } finally {
      if (mounted) {
        setState(() => _sharingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final invoice = _invoice;
    final organization = _resolveOrganization();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          invoice == null
              ? loc.invoiceDetailTitle
              : '${invoice.documentTitle} ${invoice.number}',
        ),
        actions: [
          if (invoice != null) ...[
            IconButton(
              tooltip: isSw
                  ? 'Hariri Nembo & Maelezo ya Benki'
                  : 'Edit Logo & Bank Info',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => showInvoiceBrandingSheet(context),
            ),
            IconButton(
              tooltip:
                  isSw ? 'Pakua / Shiriki A4 PDF' : 'Share / Download A4 PDF',
              icon: _sharingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _sharingPdf
                  ? null
                  : () => _shareA4Pdf(invoice, organization, isSw),
            ),
          ],
        ],
      ),
      body: WaveBackground(
        child: invoice == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
              )
            : _buildInvoice(context, invoice, organization, loc, isSw),
      ),
    );
  }

  Widget _buildInvoice(
    BuildContext context,
    CustomerInvoice invoice,
    Organization organization,
    AppLocalizations loc,
    bool isSwahili,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Top Action Bar: Share / Print A4 PDF + Record Payment
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.print_outlined,
                color: Color(0xFF2DD4BF),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili
                          ? 'Muundo wa A4 Tayari Kuchapishwa'
                          : 'Print-Ready A4 Invoice Format',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isSwahili
                          ? 'Tuma WhatsApp/Email au chapisha kwenye karatasi ya A4'
                          : 'Share via WhatsApp/Email or print directly on A4 paper',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
                onPressed: _sharingPdf
                    ? null
                    : () => _shareA4Pdf(invoice, organization, isSwahili),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: Text(isSwahili ? 'A4 PDF' : 'Share PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InvoicePreviewScreen(
                      documentId: invoice.id,
                      documentNumber: invoice.invoiceNumber,
                    ),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(isSwahili ? 'Hakiki (PDF)' : 'Native PDF'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Live A4 Visual Preview Card
        InvoiceA4PreviewCard(
          invoice: invoice,
          organization: organization,
          isSwahili: isSwahili,
          onConfigureBranding: () => showInvoiceBrandingSheet(context),
        ),

        const SizedBox(height: 16),

        // Payment & Void Action Buttons
        Row(
          children: [
            if (invoice.canTakePayment)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _working
                      ? null
                      : () => _showPaymentSheet(context, invoice, isSwahili),
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
    bool isSwahili,
  ) async {
    final amountController =
        TextEditingController(text: invoice.balanceDue.toStringAsFixed(0));
    final methodController = TextEditingController(text: 'Bank Transfer');
    final referenceController = TextEditingController();
    final loc = context.loc;
    const methods = [
      'Bank Transfer',
      'Mobile Money',
      'Cash',
      'Cheque',
      'Card',
    ];

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final m in methods)
                          ChoiceChip(
                            label: Text(m),
                            selected: methodController.text == m,
                            onSelected: (_) => setSheetState(
                              () => methodController.text = m,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText: loc.invoicePaymentReference,
                        hintText: isSwahili
                            ? 'Namba ya muamala / Stakabadhi'
                            : 'Transaction ID / Receipt No.',
                      ),
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
}
