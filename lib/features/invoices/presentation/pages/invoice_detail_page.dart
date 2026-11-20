import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/delivery_notes_controller.dart';
import '../../application/document_template_controller.dart';
import '../../application/invoices_controller.dart';
import '../../domain/document_template.dart';
import '../../domain/invoice.dart';
import '../services/customer_invoice_pdf_service.dart';
import '../widgets/create_delivery_note_sheet.dart';
import '../widgets/invoice_a4_preview_card.dart';
import '../widgets/invoice_branding_sheet.dart';
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
      ref.read(documentTemplateControllerProvider.notifier).ensureLoaded();
      ref.read(deliveryNotesControllerProvider.notifier).load();
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
    final tplConfig =
        ref.watch(documentTemplateControllerProvider).currentInvoiceConfiguration;
    if (settingsState is SettingsLoaded) {
      if ((settingsState.organization.invoicePrefix == null ||
              settingsState.organization.invoicePrefix!.trim().isEmpty) &&
          tplConfig.invoicePrefix?.trim().isNotEmpty == true) {
        return settingsState.organization
            .copyWith(invoicePrefix: tplConfig.invoicePrefix);
      }
      return settingsState.organization;
    }
    return Organization(
      name: 'Your Business',
      currency: 'TZS',
      invoicePrefix: tplConfig.invoicePrefix,
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
      final templateConfig =
          ref.read(documentTemplateControllerProvider).currentInvoiceConfiguration;
      await ref.read(customerInvoicePdfServiceProvider).shareA4Pdf(
            invoice: invoice,
            organization: organization,
            isSwahili: isSwahili,
            templateConfig: templateConfig,
          );
    } finally {
      if (mounted) {
        setState(() => _sharingPdf = false);
      }
    }
  }

  void _navigateBackToInvoices(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.invoices);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final invoice = _invoice;
    final organization = _resolveOrganization();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigateBackToInvoices(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: isSw ? 'Rudi kwenye Orodha ya Ankara' : 'Back to Invoices',
            onPressed: () => _navigateBackToInvoices(context),
          ),
          title: Text(
            invoice == null
                ? loc.invoiceDetailTitle
                : '${invoice.documentTitle} ${invoice.displayNumber(organization.invoicePrefix)}',
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
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.resolveTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => _navigateBackToInvoices(context),
                              icon: const Icon(Icons.arrow_back),
                              label: Text(
                                isSw
                                    ? 'Rudi kwenye Orodha ya Ankara'
                                    : 'Back to Invoices List',
                              ),
                            ),
                          ],
                        ),
                )
              : _buildInvoice(context, invoice, organization, loc, isSw),
        ),
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
        // Sync State Banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: invoice.isSynced
                ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.45)
                    : AppColors.successContainer.withValues(alpha: 0.6))
                : AppColors.resolveSurfaceSecondary(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: invoice.isSynced
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.resolveBorder(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                invoice.isSynced
                    ? Icons.check_circle_rounded
                    : Icons.access_time_rounded,
                size: 16,
                color: invoice.isSynced
                    ? AppColors.success
                    : AppColors.resolveTextSecondary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.isSynced
                      ? (isSwahili
                          ? 'Ankara imelandanishwa kwenye wingu (Cloud Synced)'
                          : 'Invoice is verified and synced to cloud')
                      : (isSwahili
                          ? 'Imehifadhiwa ndani ya simu (Inasubiri intaneti kulandanishwa)'
                          : 'Stored locally on-device (Waiting for connection to sync)'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: invoice.isSynced
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFA7F3D0)
                            : AppColors.onSuccessContainer)
                        : AppColors.resolveTextSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top Action Bar: Share / Print A4 PDF + Preview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : AppColors.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.print_outlined,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2DD4BF)
                        : Theme.of(context).colorScheme.primary,
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
                          style: TextStyle(
                            color: AppColors.resolveTextPrimary(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSwahili
                              ? 'Tuma WhatsApp/Email au chapisha moja kwa moja kwenye karatasi ya A4'
                              : 'Share via WhatsApp/Email or print directly on A4 paper',
                          style: TextStyle(
                            color: AppColors.resolveTextSecondary(context),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0D9488)
                                : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sharingPdf
                          ? null
                          : () => _shareA4Pdf(invoice, organization, isSwahili),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: Text(
                        isSwahili ? 'Tuma A4 PDF' : 'Share A4 PDF',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF64748B)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => InvoicePreviewScreen(
                            documentId: invoice.id,
                            documentNumber:
                                invoice.displayNumber(organization.invoicePrefix),
                            initialInvoice: invoice,
                          ),
                        ),
                      ),
                      icon:
                          const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: Text(
                        isSwahili ? 'Hakiki & Chapisha' : 'Preview & Print',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Convert to Tax Invoice Action Card (if not already Tax Invoice)
        if (!invoice.isTaxInvoice) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSwahili
                            ? 'Badilisha kuwa Tax Invoice'
                            : 'Convert to Tax Invoice',
                        style: TextStyle(
                          color: AppColors.resolveTextPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSwahili
                            ? (invoice.isProforma
                                ? 'Ankara ya makadirio (Proforma) inaweza kubadilishwa kuwa Ankara Rasmi ya Kodi (18% VAT)'
                                : 'Ongeza kodi ya VAT na VRN ya mteja kuifanya Ankara Rasmi ya Kodi')
                            : 'Convert this invoice into an official Tax Invoice with VAT and customer VRN',
                        style: TextStyle(
                          color: AppColors.resolveTextSecondary(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _promptConvertToTaxInvoice(
                      invoice, organization, isSwahili),
                  icon: const Icon(Icons.transform_outlined, size: 16),
                  label: Text(isSwahili ? 'Badilisha' : 'Convert'),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Delivery Note Action Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF334155)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF0D9488),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.invoiceGenerateDeliveryNote,
                      style: TextStyle(
                        color: AppColors.resolveTextPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.invoiceDeliveryNoteSubtitle,
                      style: TextStyle(
                        color: AppColors.resolveTextSecondary(context),
                        fontSize: 11.5,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () async {
                  final created = await showCreateDeliveryNoteSheet(
                    context,
                    invoice: invoice,
                    organization: organization,
                  );
                  if (created != null) {
                    ref.read(deliveryNotesControllerProvider.notifier).refresh();
                  }
                },
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: Text(isSwahili ? 'Toa Waraka' : 'Dispatch'),
              ),
            ],
          ),
        ),

        // Issued Delivery Notes List for this Invoice
        if (ref.watch(deliveryNotesControllerProvider) is DeliveryNotesLoaded) ...[
          () {
            final dnLoaded =
                ref.watch(deliveryNotesControllerProvider) as DeliveryNotesLoaded;
            final invoiceNotes =
                dnLoaded.items.where((n) => n.invoiceId == invoice.id).toList();
            if (invoiceNotes.isEmpty) return const SizedBox.shrink();

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF132220)
                    : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 18,
                            color: Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSwahili
                                ? 'Waraka wa Mzigo Uliotolewa (${invoiceNotes.length})'
                                : 'Issued Delivery Notes (${invoiceNotes.length})',
                            style: TextStyle(
                              color: AppColors.resolveTextPrimary(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isSwahili ? 'Mizigo' : 'Dispatches',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final note in invoiceNotes)
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => InvoicePreviewScreen(
                              documentId: note.id,
                              documentNumber: note.number,
                              documentType: DocumentType.deliveryNote,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.resolveBorder(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.number,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color:
                                          AppColors.resolveTextPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSwahili
                                        ? '${note.itemCount} bidhaa • ${DateFormat('dd/MM/yyyy HH:mm').format(note.issueDate)}'
                                        : '${note.itemCount} items • ${DateFormat('dd/MM/yyyy HH:mm').format(note.issueDate)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppColors.resolveTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => InvoicePreviewScreen(
                                      documentId: note.id,
                                      documentNumber: note.number,
                                      documentType: DocumentType.deliveryNote,
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.print_outlined, size: 14),
                              label: Text(
                                isSwahili ? 'Fungua / Print' : 'View / Print',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }(),
        ],

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

        const SizedBox(height: 14),

        // Return to Invoices List Action Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _navigateBackToInvoices(context),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(
            isSwahili ? 'Rudi kwenye Orodha ya Ankara' : 'Back to Invoices List',
          ),
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
        backgroundColor: AppColors.resolveCardBackground(context),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.resolveTextPrimary(sheetContext),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      style: TextStyle(
                        color: AppColors.resolveTextPrimary(sheetContext),
                        fontWeight: FontWeight.w600,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: loc.invoicePaymentAmount,
                        helperText:
                            '${loc.invoiceBalance}: ${formatMoney(invoice.balanceDue)}',
                        helperStyle: TextStyle(
                          color: AppColors.resolveTextSecondary(sheetContext),
                        ),
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
                            selectedColor: AppColors.primaryContainer,
                            backgroundColor:
                                AppColors.resolveSurfaceSecondary(sheetContext),
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: methodController.text == m
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: methodController.text == m
                                  ? AppColors.primary
                                  : AppColors.resolveTextPrimary(sheetContext),
                            ),
                            onSelected: (_) => setSheetState(
                              () => methodController.text = m,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceController,
                      style: TextStyle(
                        color: AppColors.resolveTextPrimary(sheetContext),
                      ),
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

  Future<void> _promptConvertToTaxInvoice(
    CustomerInvoice invoice,
    Organization organization,
    bool isSwahili,
  ) async {
    final vrnController =
        TextEditingController(text: invoice.customerVrn ?? '');
    final vatRate =
        organization.defaultVatRate > 0 ? organization.defaultVatRate : 18.0;
    bool isTaxInclusive = organization.isTaxInclusive;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (innerContext, setModalState) {
              final subtotal = invoice.subtotal;
              double previewSubtotal;
              double previewTax;
              double previewTotal;

              if (isTaxInclusive) {
                previewSubtotal = subtotal / (1.0 + (vatRate / 100.0));
                previewTax = subtotal - previewSubtotal;
                previewTotal = subtotal;
              } else {
                previewSubtotal = subtotal;
                previewTax = subtotal * (vatRate / 100.0);
                previewTotal =
                    (previewSubtotal - invoice.discountAmount) + previewTax;
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSwahili
                                    ? 'Badilisha kuwa Tax Invoice'
                                    : 'Convert to Tax Invoice',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                isSwahili
                                    ? 'Hesabu VAT ya ${vatRate.toStringAsFixed(0)}% kisheria'
                                    : 'Compute ${vatRate.toStringAsFixed(0)}% VAT legally',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.resolveTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: vrnController,
                      style: TextStyle(
                        color: AppColors.resolveTextPrimary(sheetContext),
                      ),
                      decoration: InputDecoration(
                        labelText: isSwahili
                            ? 'Namba ya VRN ya Mteja (Hiari)'
                            : 'Customer VRN (Optional)',
                        hintText: isSwahili
                            ? 'Mfano: 40-123456-X'
                            : 'e.g. 40-123456-X',
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isSwahili
                            ? 'Bei ya sasa inajumuisha VAT'
                            : 'Current price already includes VAT',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isSwahili
                            ? 'Jumla ya ankara haitaongezeka, VAT itatenganishwa'
                            : 'Invoice total won\'t increase, VAT will be extracted',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                      value: isTaxInclusive,
                      onChanged: (val) {
                        setModalState(() {
                          isTaxInclusive = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isSwahili
                                    ? 'Kiasi kabla ya Kodi:'
                                    : 'Taxable Subtotal:',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                formatMoney(previewSubtotal,
                                    symbol: invoice.currency),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${isSwahili ? "VAT" : "VAT"} @ ${vatRate.toStringAsFixed(0)}%:',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF2563EB)),
                              ),
                              Text(
                                formatMoney(previewTax,
                                    symbol: invoice.currency),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isSwahili
                                    ? 'Jumla Kuu Mpya:'
                                    : 'New Total Gross:',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                formatMoney(previewTotal,
                                    symbol: invoice.currency),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        isSwahili
                            ? 'Thibitisha na Badilisha kuwa Tax Invoice'
                            : 'Confirm & Convert to Tax Invoice',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final vrn = _orNull(vrnController.text);
                        await _run(() => ref
                            .read(invoicesControllerProvider.notifier)
                            .convertToTaxInvoice(
                              id: invoice.id,
                              vatRate: vatRate,
                              customerVrn: vrn,
                              isTaxInclusive: isTaxInclusive,
                            ));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSwahili
                                  ? 'Ankara imebadilishwa kuwa Tax Invoice yenye VAT!'
                                  : 'Invoice successfully converted to Tax Invoice!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      vrnController.dispose();
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
