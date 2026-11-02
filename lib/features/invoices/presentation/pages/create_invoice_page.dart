import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../products/application/products_controller.dart';
import '../../../products/domain/product.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/invoices_controller.dart';
import '../../domain/invoice.dart';
import '../widgets/invoice_branding_sheet.dart';

class CreateInvoicePage extends ConsumerStatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  ConsumerState<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends ConsumerState<CreateInvoicePage> {
  static const List<String> _documentTitles = [
    'INVOICE',
    'PROFORMA INVOICE',
    'QUOTATION',
  ];

  static const List<(String, int?)> _paymentTermPresets = [
    ('Due on Receipt', 0),
    ('Net 7', 7),
    ('Net 14', 14),
    ('Net 30', 30),
  ];

  static const List<String> _unitsOfMeasure = [
    'Pcs',
    'Service',
    'Hours',
    'Days',
    'Bags',
    'Kg',
    'Boxes',
    'Trips',
    'Meters',
    'Lot',
  ];

  static const List<String> _paymentMethods = [
    'Bank Transfer',
    'Mobile Money',
    'Cash',
    'Cheque',
    'Card',
  ];

  String _documentTitle = 'INVOICE';
  String _paymentTerms = 'Net 14';
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 14));

  final _issueDateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _customerId;
  final _customerNameController = TextEditingController();
  final _customerAttentionController = TextEditingController();
  final _customerTinController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  bool _showExtraClientFields = false;

  final _lines = <_LineInputs>[_LineInputs()];
  final _invoiceDiscountController = TextEditingController();

  bool _hasInitialDeposit = false;
  final _initialPaidController = TextEditingController();
  String _initialPaymentMethod = 'Bank Transfer';
  final _initialPaymentReferenceController = TextEditingController();

  final _paymentInstructionsController = TextEditingController();
  final _notesController = TextEditingController();
  final _signatoryNameController = TextEditingController();
  final _signatoryTitleController = TextEditingController();
  bool _prefilledFromOrg = false;

  bool _saving = false;
  final String _invoiceId = const Uuid().v4();
  String? _error;

  @override
  void initState() {
    super.initState();
    _issueDateController.text = _isoDate(_issueDate);
    _dueDateController.text = _isoDate(_dueDate!);
    Future.microtask(() {
      ref.read(customersControllerProvider.notifier).load();
      ref.read(productsControllerProvider.notifier).load();
      ref.read(settingsControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _dueDateController.dispose();
    _referenceController.dispose();
    _customerNameController.dispose();
    _customerAttentionController.dispose();
    _customerTinController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _invoiceDiscountController.dispose();
    _initialPaidController.dispose();
    _initialPaymentReferenceController.dispose();
    _paymentInstructionsController.dispose();
    _notesController.dispose();
    _signatoryNameController.dispose();
    _signatoryTitleController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _syncDefaultsFromOrganization(Organization org) {
    if (_prefilledFromOrg) return;
    _prefilledFromOrg = true;

    final bankLines = <String>[];
    if (org.bankName != null && org.bankName!.trim().isNotEmpty) {
      bankLines.add('Bank: ${org.bankName!.trim()}');
    }
    if (org.bankAccountName != null && org.bankAccountName!.trim().isNotEmpty) {
      bankLines.add('Account Name: ${org.bankAccountName!.trim()}');
    }
    if (org.bankAccountNumber != null &&
        org.bankAccountNumber!.trim().isNotEmpty) {
      bankLines.add('Account No: ${org.bankAccountNumber!.trim()}');
    }
    if (org.bankBranchOrSwift != null &&
        org.bankBranchOrSwift!.trim().isNotEmpty) {
      bankLines.add('Branch / SWIFT: ${org.bankBranchOrSwift!.trim()}');
    }
    if (org.mobileMoneyDetails != null &&
        org.mobileMoneyDetails!.trim().isNotEmpty) {
      bankLines.add('Mobile Money: ${org.mobileMoneyDetails!.trim()}');
    }
    if (_paymentInstructionsController.text.isEmpty && bankLines.isNotEmpty) {
      _paymentInstructionsController.text = bankLines.join('\n');
    }
    if (_notesController.text.isEmpty &&
        org.invoiceTerms != null &&
        org.invoiceTerms!.trim().isNotEmpty) {
      _notesController.text = org.invoiceTerms!.trim();
    }
    if (_signatoryNameController.text.isEmpty &&
        org.authorizedSignatoryName != null &&
        org.authorizedSignatoryName!.trim().isNotEmpty) {
      _signatoryNameController.text = org.authorizedSignatoryName!.trim();
    }
    if (_signatoryTitleController.text.isEmpty &&
        org.authorizedSignatoryTitle != null &&
        org.authorizedSignatoryTitle!.trim().isNotEmpty) {
      _signatoryTitleController.text = org.authorizedSignatoryTitle!.trim();
    }
  }

  double get _subtotal => _lines.fold(0, (sum, line) => sum + line.lineTotal);

  double get _invoiceDiscount =>
      double.tryParse(_invoiceDiscountController.text.trim()) ?? 0;

  double get _totalAmount {
    final total = _subtotal - _invoiceDiscount;
    return total < 0 ? 0 : total;
  }

  double get _initialPaid => _hasInitialDeposit
      ? (double.tryParse(_initialPaidController.text.trim()) ?? 0)
      : 0;

  double get _balanceDue {
    final bal = _totalAmount - _initialPaid;
    return bal < 0 ? 0 : bal;
  }

  int _step = 0;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _customerNameController.text.trim().isNotEmpty ||
            _customerId == null;
      case 1:
        return _lines.any((line) => line.description.text.trim().isNotEmpty);
      default:
        return true;
    }
  }

  bool get _canSave =>
      !_saving && _lines.any((line) => line.description.text.trim().isNotEmpty);

  void _onSelectCustomer(
    String? id,
    List<Map<String, dynamic>> customerItems,
  ) {
    setState(() {
      _customerId = id;
      if (id == null) return;
      final found = customerItems.where((c) => c['id'] == id).firstOrNull;
      if (found != null) {
        _customerNameController.text =
            ((found['name'] as String?) ?? '').trim();
        _customerPhoneController.text =
            ((found['phone'] as String?) ?? '').trim();
        _customerEmailController.text =
            ((found['email'] as String?) ?? '').trim();
        _customerTinController.text =
            ((found['taxId'] as String?) ?? (found['tin'] as String?) ?? '')
                .trim();
        _customerAddressController.text =
            ((found['address'] as String?) ?? '').trim();
        if (_customerTinController.text.isNotEmpty ||
            _customerAddressController.text.isNotEmpty ||
            _customerEmailController.text.isNotEmpty) {
          _showExtraClientFields = true;
        }
      }
    });
  }

  void _applyPaymentTermPreset(String term, int? days) {
    setState(() {
      _paymentTerms = term;
      if (days != null) {
        final nextDue = _issueDate.add(Duration(days: days));
        _dueDate = nextDue;
        _dueDateController.text = _isoDate(nextDue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final customersState = ref.watch(customersControllerProvider);
    final customerItems = customersState is CustomersLoaded
        ? customersState.items
        : const <Map<String, dynamic>>[];
    final customerIds = <String, String>{
      for (final customer in customerItems)
        if (customer['id'] is String)
          customer['id'] as String:
              ((customer['name'] as String?) ?? '').trim(),
    };

    final settingsState = ref.watch(settingsControllerProvider);
    final org =
        settingsState is SettingsLoaded ? settingsState.organization : null;
    if (org != null) {
      _syncDefaultsFromOrganization(org);
    }

    final textPrimary = AppColors.resolveTextPrimary(context);
    final textSecondary = AppColors.resolveTextSecondary(context);
    final cardBg = AppColors.resolveCardBackground(context);
    final borderColor = AppColors.resolveBorder(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.invoiceNewTitle),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await showInvoiceBrandingSheet(context);
              if (mounted) {
                setState(() => _prefilledFromOrg = false);
              }
            },
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: Text(isSw ? 'Nembo & Benki' : 'Logo & Bank'),
          ),
        ],
      ),
      body: WaveBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _WizardStepper(
              step: _step,
              isSwahili: isSw,
              onTap: (i) {
                if (i < _step) setState(() => _step = i);
              },
            ),
            const SizedBox(height: 10),
            if (org != null)
              _SenderChip(organization: org, isSwahili: isSw),
            const SizedBox(height: 12),

            if (_step == 0) ...[
              // 2. Document Type & Tracking Metadata Card
              Card(
                elevation: isDark ? 0 : 0.5,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.description_outlined,
                        title: isSw
                            ? '1. Aina ya Hati & Tarehe'
                            : '1. Document Type & Dates',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final docTitle in _documentTitles)
                            ChoiceChip(
                              label: Text(docTitle),
                              selected: _documentTitle == docTitle,
                              selectedColor: AppColors.primaryContainer,
                              backgroundColor:
                                  AppColors.resolveSurfaceSecondary(context),
                              side: BorderSide(
                                color: _documentTitle == docTitle
                                    ? AppColors.primary
                                    : borderColor,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _documentTitle == docTitle
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _documentTitle == docTitle
                                    ? AppColors.primary
                                    : textPrimary,
                              ),
                              onSelected: (_) =>
                                  setState(() => _documentTitle = docTitle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isSw
                            ? 'Masharti ya Malipo (Payment Terms)'
                            : 'Payment Terms',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final (term, days) in _paymentTermPresets)
                            ChoiceChip(
                              label: Text(term),
                              selected: _paymentTerms == term,
                              selectedColor: AppColors.primaryContainer,
                              backgroundColor:
                                  AppColors.resolveSurfaceSecondary(context),
                              side: BorderSide(
                                color: _paymentTerms == term
                                    ? AppColors.primary
                                    : borderColor,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _paymentTerms == term
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _paymentTerms == term
                                    ? AppColors.primary
                                    : textPrimary,
                              ),
                              onSelected: (_) =>
                                  _applyPaymentTermPreset(term, days),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _issueDateController,
                              readOnly: true,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    isSw ? 'Tarehe ya Kutolewa' : 'Issue Date',
                                prefixIcon:
                                    const Icon(Icons.calendar_today, size: 18),
                              ),
                              onTap: _pickIssueDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _dueDateController,
                              readOnly: true,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: loc.invoiceDueDate,
                                hintText: 'YYYY-MM-DD',
                                prefixIcon:
                                    const Icon(Icons.event_outlined, size: 18),
                              ),
                              onTap: _pickDueDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _referenceController,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: isSw
                              ? 'Namba ya Kumbukumbu / LPO / Nukuu (Hiari)'
                              : 'Reference / PO / Quote Number (Optional)',
                          hintText: isSw
                              ? 'Mfano: PO-2026-089 au Mkataba #12'
                              : 'e.g. PO-2026-089 or Quote #104',
                          prefixIcon: const Icon(Icons.tag, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Client ("Bill To") Card
              Card(
                elevation: isDark ? 0 : 0.5,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.person_outline,
                        title: isSw
                            ? '2. Taarifa za Mteja (Bill To)'
                            : '2. Client ("Bill To") Details',
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _customerId,
                        isExpanded: true,
                        dropdownColor: cardBg,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: loc.invoiceCustomer,
                          prefixIcon:
                              const Icon(Icons.people_alt_outlined, size: 18),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              loc.invoiceWalkIn,
                              style: TextStyle(color: textPrimary),
                            ),
                          ),
                          for (final entry in customerIds.entries)
                            DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: TextStyle(color: textPrimary),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            _onSelectCustomer(value, customerItems),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _customerNameController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: isSw
                                    ? 'Jina la Mteja / Kampuni'
                                    : 'Client / Company Name',
                                hintText: isSw
                                    ? 'Mfano: Kilimanjaro Logistics Ltd'
                                    : 'e.g. Acme Builders Ltd',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _customerPhoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    isSw ? 'Simu ya Mteja' : 'Client Phone',
                                hintText: '+255...',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () =>
                                _showExtraClientFields = !_showExtraClientFields,
                          ),
                          icon: Icon(
                            _showExtraClientFields
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                          ),
                          label: Text(
                            _showExtraClientFields
                                ? (isSw
                                    ? 'Ficha TIN, Anwani & Barua Pepe'
                                    : 'Hide Client TIN, Address & Email')
                                : (isSw
                                    ? 'Ongeza TIN ya Mteja, Anwani & Mhusika'
                                    : 'Add Client TIN, Attention, Email & Address'),
                          ),
                        ),
                      ),
                      if (_showExtraClientFields) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customerTinController,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      isSw ? 'TIN ya Mteja' : 'Client TIN',
                                  hintText: '123-456-789',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _customerAttentionController,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: isSw
                                      ? 'Kwa Uangalizi wa (Attn)'
                                      : 'Attention / Contact Person',
                                  hintText: isSw
                                      ? 'Mfano: Meneja Manunuzi'
                                      : 'e.g. Procurement Manager',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customerEmailController,
                                keyboardType: TextInputType.emailAddress,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: isSw
                                      ? 'Barua Pepe ya Mteja'
                                      : 'Client Email',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _customerAddressController,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      isSw ? 'Anwani ya Mteja' : 'Client Address',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            if (_step == 1) ...[
              // 4. Itemised Line Items Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionHeader(
                    icon: Icons.format_list_numbered_outlined,
                    title: isSw
                        ? '3. Bidhaa au Huduma (Line Items)'
                        : '3. Itemised Products / Services',
                  ),
                  TextButton.icon(
                    onPressed: _pickFromCatalogForNewLine,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(isSw ? 'Chagua Katalogi' : 'From Catalog'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _lines.length; i++)
                _LineCard(
                  index: i,
                  inputs: _lines[i],
                  unitsOfMeasure: _unitsOfMeasure,
                  canRemove: _lines.length > 1,
                  isSwahili: isSw,
                  onChanged: () => setState(() {}),
                  onPickCatalog: () => _pickProductForLine(_lines[i]),
                  onRemove: () {
                    setState(() {
                      final removed = _lines.removeAt(i);
                      removed.dispose();
                    });
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineInputs())),
                  icon: const Icon(Icons.add),
                  label: Text(loc.invoiceAddLine),
                ),
              ),
            ],

            if (_step == 2) ...[
              // 5. Financial Summary & Initial Deposit Card
              Card(
                elevation: isDark ? 0 : 0.5,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(
                        icon: Icons.calculate_outlined,
                        title: isSw
                            ? '4. Muhtasari wa Fedha & Malipo ya Awali'
                            : '4. Financial Summary & Deposit',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSw ? 'Jumla Ndogo (Subtotal)' : 'Subtotal',
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            formatMoney(_subtotal),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _invoiceDiscountController,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: isSw
                              ? 'Punguzo la Ankara (Invoice Discount)'
                              : 'Invoice Discount (Optional)',
                          prefixIcon:
                              const Icon(Icons.discount_outlined, size: 18),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.invoiceTotal,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            formatMoney(_totalAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isSw
                              ? 'Weka Malipo ya Awali / Advance (Deposit)'
                              : 'Record Initial Deposit / Advance Paid',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        value: _hasInitialDeposit,
                        onChanged: (val) =>
                            setState(() => _hasInitialDeposit = val),
                      ),
                      if (_hasInitialDeposit) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _initialPaidController,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: isSw
                                      ? 'Kiasi Kilicholipwa'
                                      : 'Amount Paid Now',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _initialPaymentMethod,
                                isExpanded: true,
                                dropdownColor: cardBg,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.invoicePaymentMethod,
                                ),
                                items: [
                                  for (final method in _paymentMethods)
                                    DropdownMenuItem(
                                      value: method,
                                      child: Text(
                                        method,
                                        style: TextStyle(color: textPrimary),
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _initialPaymentMethod = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _initialPaymentReferenceController,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: loc.invoicePaymentReference,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isSw ? 'SALIO LA KULIPWA' : 'BALANCE DUE',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formatMoney(_balanceDue),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _SenderInfoCard(
                isSwahili: isSw,
                organization: org,
                onOpenProfile: () async {
                  await showInvoiceBrandingSheet(context);
                  if (mounted) {
                    setState(() => _prefilledFromOrg = false);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: loc.invoiceNotes,
                  hintText: isSw
                      ? 'Maelezo ya ziada kwa ankara hii (hiari)...'
                      : 'Optional note for this invoice...',
                ),
              ),
            ],

            if (_step == 3) ...[
              _ReviewCard(
                isSwahili: isSw,
                organization: org,
                customerName: _customerNameController.text.trim(),
                documentTitle: _documentTitle,
                lineCount: _lines
                    .where((l) => l.description.text.trim().isNotEmpty)
                    .length,
                subtotal: _subtotal,
                discount: _invoiceDiscount,
                total: _totalAmount,
                paid: _initialPaid,
                balance: _balanceDue,
                paymentInstructions: _paymentInstructionsController.text.trim(),
                notes: _notesController.text.trim(),
                onEditCustomer: () => setState(() => _step = 0),
                onEditItems: () => setState(() => _step = 1),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.resolveCardBackground(context),
          border: Border(
            top: BorderSide(
              color: AppColors.resolveBorder(context),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.25
                    : 0.05,
              ),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _step--),
                    child: Text(isSw ? 'Rudi' : 'Back'),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _step < 3
                          ? (_canContinue ? () => setState(() => _step++) : null)
                          : (_canSave ? _save : null),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _step < 3
                                  ? Icons.arrow_forward
                                  : Icons.check_circle_outline,
                            ),
                      label: Text(
                        _step < 2
                            ? (isSw ? 'Endelea' : 'Continue')
                            : _step == 2
                                ? (isSw ? 'Kagua Ankara' : 'Review invoice')
                                : loc.invoiceSave,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickIssueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _issueDate = picked;
      _issueDateController.text = _isoDate(picked);
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = picked;
      _dueDateController.text = _isoDate(picked);
    });
  }

  Future<void> _pickFromCatalogForNewLine() async {
    final targetLine = _lines.firstWhere(
      (l) => l.description.text.trim().isEmpty,
      orElse: () {
        final added = _LineInputs();
        setState(() => _lines.add(added));
        return added;
      },
    );
    await _pickProductForLine(targetLine);
  }

  Future<void> _pickProductForLine(_LineInputs line) async {
    final productsState = ref.read(productsControllerProvider);
    final items = productsState is ProductsLoaded
        ? productsState.items
        : const <Product>[];
    final prices = productsState is ProductsLoaded
        ? productsState.prices
        : const <String, double>{};

    if (items.isEmpty) {
      await ref.read(productsControllerProvider.notifier).load();
    }
    if (!mounted) return;

    final updatedState = ref.read(productsControllerProvider);
    final availableProducts = updatedState is ProductsLoaded
        ? updatedState.items
        : items;
    final availablePrices = updatedState is ProductsLoaded
        ? updatedState.prices
        : prices;

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.resolveCardBackground(context),
      builder: (sheetCtx) => _CatalogPickerSheet(
        products: availableProducts,
        prices: availablePrices,
      ),
    );

    if (selected != null && mounted) {
      final price =
          availablePrices[selected.id] ?? selected.costPrice ?? 0;
      setState(() {
        line.productId = selected.id;
        line.description.text = selected.name;
        if (price > 0) {
          line.unitPrice.text = price.toStringAsFixed(0);
        }
        line.unitOfMeasure =
            selected.productType == ProductType.service ? 'Service' : 'Pcs';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    setState(() {
      _error = null;
    });

    final drafts = _lines
        .where((line) => line.description.text.trim().isNotEmpty)
        .map(
          (line) => InvoiceDraftLine(
            productId: line.productId,
            description: line.description.text.trim(),
            unitOfMeasure: line.unitOfMeasure,
            quantity: line.parsedQuantity,
            unitPrice: line.parsedUnitPrice,
            discountAmount: line.parsedDiscount,
            taxRatePercent: 0,
          ),
        )
        .toList(growable: false);

    final invoice = await ref.read(invoicesControllerProvider.notifier).create(
          id: _invoiceId,
          lines: drafts,
          documentTitle: _documentTitle,
          referenceNumber: _referenceController.text,
          paymentTerms: _paymentTerms,
          customerId: _customerId,
          customerName: _customerNameController.text,
          customerAttention: _customerAttentionController.text,
          customerPhone: _customerPhoneController.text,
          customerEmail: _customerEmailController.text,
          customerAddress: _customerAddressController.text,
          customerTin: _customerTinController.text,
          issueDate: _issueDate,
          dueDate: _dueDate,
          discountAmount: _invoiceDiscount,
          initialAmountPaid: _initialPaid,
          paymentMethod: _hasInitialDeposit ? _initialPaymentMethod : null,
          paymentReference: _hasInitialDeposit
              ? _initialPaymentReferenceController.text
              : null,
          notes: _notesController.text,
          paymentInstructions: _paymentInstructionsController.text,
          authorizedSignatoryName: _signatoryNameController.text,
          authorizedSignatoryTitle: _signatoryTitleController.text,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (invoice == null) {
      final state = ref.read(invoicesControllerProvider);
      setState(
        () => _error = state is InvoicesFailure
            ? state.message
            : 'Ankara haikuweza kuhifadhiwa.',
      );
      return;
    }
    context.go(Routes.invoiceDetail(invoice.id));
  }

  static String _isoDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.resolveTextPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _LineInputs {
  String? productId;
  String unitOfMeasure = 'Pcs';
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  final discount = TextEditingController();

  double get parsedQuantity => double.tryParse(quantity.text.trim()) ?? 1;

  double get parsedUnitPrice => double.tryParse(unitPrice.text.trim()) ?? 0;

  double get parsedDiscount => double.tryParse(discount.text.trim()) ?? 0;

  double get lineTotal {
    final gross = parsedQuantity * parsedUnitPrice;
    final net = gross - parsedDiscount;
    return net < 0 ? 0 : net;
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.index,
    required this.inputs,
    required this.unitsOfMeasure,
    required this.canRemove,
    required this.isSwahili,
    required this.onChanged,
    required this.onPickCatalog,
    required this.onRemove,
  });

  final int index;
  final _LineInputs inputs;
  final List<String> unitsOfMeasure;
  final bool canRemove;
  final bool isSwahili;
  final VoidCallback onChanged;
  final VoidCallback onPickCatalog;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.resolveTextPrimary(context);
    final cardBg = AppColors.resolveCardBackground(context);

    return Card(
      elevation: isDark ? 0 : 0.5,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.resolveBorder(context)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: inputs.description,
                    onChanged: (_) => onChanged(),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: loc.invoiceLineDescription,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        tooltip: isSwahili
                            ? 'Chagua kutoka katalogi'
                            : 'Pick from catalog',
                        onPressed: onPickCatalog,
                      ),
                    ),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                    tooltip: loc.invoiceRemoveLine,
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: unitsOfMeasure.contains(inputs.unitOfMeasure)
                        ? inputs.unitOfMeasure
                        : unitsOfMeasure.first,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: isSwahili ? 'Kipimo' : 'Unit',
                    ),
                    items: [
                      for (final u in unitsOfMeasure)
                        DropdownMenuItem(
                          value: u,
                          child: Text(u, style: TextStyle(color: textPrimary)),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        inputs.unitOfMeasure = val;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: inputs.quantity,
                    onChanged: (_) => onChanged(),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: loc.invoiceLineQuantity),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: inputs.unitPrice,
                    onChanged: (_) => onChanged(),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: loc.invoiceLineUnitPrice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${isSwahili ? "Jumla ya Mstari" : "Line Total"}: ${formatMoney(inputs.lineTotal)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPickerSheet extends StatefulWidget {
  const _CatalogPickerSheet({
    required this.products,
    required this.prices,
  });

  final List<Product> products;
  final Map<String, double> prices;

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final textPrimary = AppColors.resolveTextPrimary(context);
    final textSecondary = AppColors.resolveTextSecondary(context);
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(_query) ||
                  (p.sku?.toLowerCase().contains(_query) ?? false),
            )
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSw
                    ? 'Chagua Bidhaa au Huduma'
                    : 'Select Product or Service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: isSw ? 'Tafuta bidhaa...' : 'Search catalog...',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          isSw
                              ? 'Hakuna bidhaa iliyopatikana.'
                              : 'No matching products found.',
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final price = widget.prices[product.id] ??
                              product.costPrice ??
                              0;
                          return ListTile(
                            title: Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: product.sku != null
                                ? Text(
                                    'SKU: ${product.sku}',
                                    style: TextStyle(color: textSecondary),
                                  )
                                : null,
                            trailing: Text(
                              formatMoney(price),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({
    required this.step,
    required this.isSwahili,
    required this.onTap,
  });

  final int step;
  final bool isSwahili;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final labels = isSwahili
        ? const ['Mteja', 'Bidhaa', 'Malipo', 'Kagua']
        : const ['Customer', 'Items', 'Payment', 'Review'];
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i <= step
                        ? primary
                        : AppColors.resolveBorder(context),
                    child: i < step
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i <= step
                                  ? Colors.white
                                  : AppColors.resolveTextSecondary(context),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i == step
                          ? primary
                          : AppColors.resolveTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SenderChip extends StatelessWidget {
  const _SenderChip({required this.organization, required this.isSwahili});

  final Organization organization;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    final name = (organization.name != null && organization.name!.isNotEmpty)
        ? organization.name!
        : (isSwahili ? 'Biashara Yako' : 'Your Business');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : AppColors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.resolveBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 18,
            color: isDark ? const Color(0xFF93C5FD) : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${isSwahili ? 'Kutoka' : 'From'}: $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.resolveTextPrimary(context),
              ),
            ),
          ),
          Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.resolveTextTertiary(context),
          ),
        ],
      ),
    );
  }
}

class _SenderInfoCard extends StatelessWidget {
  const _SenderInfoCard({
    required this.isSwahili,
    required this.organization,
    required this.onOpenProfile,
  });

  final bool isSwahili;
  final Organization? organization;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final org = organization;
    final hasBank = org != null &&
        ((org.bankName?.trim().isNotEmpty ?? false) ||
            (org.mobileMoneyDetails?.trim().isNotEmpty ?? false));
    final hasName = org != null && (org.name?.trim().isNotEmpty ?? false);
    final complete = hasBank && hasName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 0.5,
      color: AppColors.resolveCardBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.resolveBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              complete ? Icons.verified_outlined : Icons.info_outline,
              color: complete ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                complete
                    ? (isSwahili
                        ? 'Benki, masharti na sahihi vinatoka kwenye Wasifu wa Kampuni.'
                        : 'Bank, terms and signatory come from your Company Profile.')
                    : (isSwahili
                        ? 'Wasifu wa kampuni haujakamilika. Ongeza benki / Lipa Namba ili ionekane kwenye ankara.'
                        : 'Company Profile is incomplete. Add bank / mobile money so it shows on invoices.'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenProfile,
              child: Text(isSwahili ? 'Hariri' : 'Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.isSwahili,
    required this.organization,
    required this.customerName,
    required this.documentTitle,
    required this.lineCount,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.balance,
    required this.paymentInstructions,
    required this.notes,
    required this.onEditCustomer,
    required this.onEditItems,
  });

  final bool isSwahili;
  final Organization? organization;
  final String customerName;
  final String documentTitle;
  final int lineCount;
  final double subtotal;
  final double discount;
  final double total;
  final double paid;
  final double balance;
  final String paymentInstructions;
  final String notes;
  final VoidCallback onEditCustomer;
  final VoidCallback onEditItems;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.resolveTextPrimary(context);
    final textSecondary = AppColors.resolveTextSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: bold ? textPrimary : textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return Card(
      elevation: isDark ? 0 : 0.5,
      color: AppColors.resolveCardBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.resolveBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              documentTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${isSwahili ? 'Kutoka' : 'From'}: ${organization?.name ?? '-'}',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${isSwahili ? 'Kwa' : 'To'}: '
                    '${customerName.isEmpty ? (isSwahili ? 'Mteja wa kawaida' : 'Walk-in customer') : customerName}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEditCustomer,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$lineCount ${isSwahili ? 'bidhaa / huduma' : 'item(s)'}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEditItems,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(),
            row(isSwahili ? 'Jumla Ndogo' : 'Subtotal', formatMoney(subtotal)),
            if (discount > 0)
              row(isSwahili ? 'Punguzo' : 'Discount', formatMoney(discount)),
            row(isSwahili ? 'Jumla' : 'Total', formatMoney(total), bold: true),
            if (paid > 0)
              row(isSwahili ? 'Imelipwa' : 'Paid', formatMoney(paid)),
            row(
              isSwahili ? 'Salio' : 'Balance due',
              formatMoney(balance),
              bold: true,
            ),
            if (paymentInstructions.isNotEmpty) ...[
              const Divider(),
              Text(
                paymentInstructions,
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
