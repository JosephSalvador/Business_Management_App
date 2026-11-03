import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/platform/logo_picker_service.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../settings/data/organization_providers.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/document_template_controller.dart';
import '../../domain/document_template.dart';

/// Opens a comprehensive bottom sheet where any business user can:
/// 1. Choose their Invoice Template Style (Modern Ribbon, Executive Corporate, Classic Grid, Custom Letterhead)
/// 2. Upload their company logo, digital signature/stamp, or full-width letterhead banner
/// 3. Configure Website, Bank Details, Mobile Money (Lipa Namba), Default Terms, and Authorized Signatory
Future<void> showInvoiceBrandingSheet(
  BuildContext context, {
  Organization? organization,
}) async {
  var org = organization ?? const Organization();
  if (organization == null) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      org = await container.read(organizationRepositoryProvider).get();
    } catch (_) {}
  }
  if (!context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.resolveCardBackground(context),
    builder: (_) => InvoiceBrandingSheet(organization: org),
  );
}

class InvoiceBrandingSheet extends ConsumerStatefulWidget {
  const InvoiceBrandingSheet({super.key, required this.organization});

  final Organization organization;

  @override
  ConsumerState<InvoiceBrandingSheet> createState() =>
      _InvoiceBrandingSheetState();
}

class _InvoiceBrandingSheetState extends ConsumerState<InvoiceBrandingSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _tinController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankAccountNameController;
  late final TextEditingController _bankAccountNumberController;
  late final TextEditingController _bankSwiftController;
  late final TextEditingController _mobileMoneyController;
  late final TextEditingController _termsController;
  late final TextEditingController _signatoryNameController;
  late final TextEditingController _signatoryTitleController;
  late final TextEditingController _monogramInitialsController;

  String? _logoBase64;
  String? _signatureBase64;
  String? _letterheadHeaderBase64;
  bool _hideHeaderForPrePrinted = false;
  double _prePrintedTopMarginMm = 45.0;

  InvoiceLayoutStyle _selectedLayoutStyle = InvoiceLayoutStyle.modernRibbon;
  String _primaryHex = '#D97706';
  String _secondaryHex = '#5B8DEF';

  bool _saving = false;
  bool _pickingLogo = false;
  bool _pickingSignature = false;
  bool _pickingLetterhead = false;
  Color _selectedBrandColor = const Color(0xFF0F2942);

  static const _brandPalette = <Color>[
    Color(0xFF0F2942), // Executive Navy
    Color(0xFFD97706), // Warm Amber (Sample Match)
    Color(0xFF1E40AF), // Royal Blue
    Color(0xFF047857), // Emerald Corporate
    Color(0xFF7C2D12), // Bronze / Terracotta
    Color(0xFF4C1D95), // Deep Indigo
    Color(0xFF991B1B), // Crimson
    Color(0xFF111827), // Charcoal Black
  ];

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _logoBase64 = org.logoBase64;
    _signatureBase64 = org.signatureBase64;
    _letterheadHeaderBase64 = org.letterheadHeaderBase64;
    _hideHeaderForPrePrinted = org.hideHeaderForPrePrinted;
    _prePrintedTopMarginMm = org.prePrintedTopMarginMm ?? 45.0;

    _nameController = TextEditingController(text: org.name ?? '');
    _tinController = TextEditingController(text: org.taxId ?? '');
    _phoneController = TextEditingController(text: org.phone ?? '');
    _emailController = TextEditingController(text: org.email ?? '');
    _websiteController = TextEditingController(text: org.website ?? '');
    _addressController = TextEditingController(text: org.address ?? '');
    _bankNameController = TextEditingController(text: org.bankName ?? '');
    _bankAccountNameController =
        TextEditingController(text: org.bankAccountName ?? '');
    _bankAccountNumberController =
        TextEditingController(text: org.bankAccountNumber ?? '');
    _bankSwiftController =
        TextEditingController(text: org.bankBranchOrSwift ?? '');
    _mobileMoneyController =
        TextEditingController(text: org.mobileMoneyDetails ?? '');
    _termsController = TextEditingController(
      text: org.invoiceTerms ??
          'Payment is due within the specified due date. Please quote the invoice number as your payment reference.',
    );
    _signatoryNameController =
        TextEditingController(text: org.authorizedSignatoryName ?? '');
    _signatoryTitleController = TextEditingController(
      text: org.authorizedSignatoryTitle ?? 'Authorized Signatory',
    );
    _monogramInitialsController = TextEditingController();

    Future.microtask(() async {
      await ref.read(documentTemplateControllerProvider.notifier).ensureLoaded();
      if (!mounted) return;
      final cfg =
          ref.read(documentTemplateControllerProvider).currentInvoiceConfiguration;
      setState(() {
        _selectedLayoutStyle = cfg.layoutStyle;
        _primaryHex = cfg.themePrimaryHex ?? _primaryHex;
        _secondaryHex = cfg.themeSecondaryHex ?? _secondaryHex;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _tinController,
      _phoneController,
      _emailController,
      _websiteController,
      _addressController,
      _bankNameController,
      _bankAccountNameController,
      _bankAccountNumberController,
      _bankSwiftController,
      _mobileMoneyController,
      _termsController,
      _signatoryNameController,
      _signatoryTitleController,
      _monogramInitialsController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogoFromGallery() async {
    if (_pickingLogo) return;
    setState(() => _pickingLogo = true);
    try {
      final picked = await LogoPickerService.pickFromDevice();
      if (!mounted) return;
      if (picked != null && picked.isNotEmpty) {
        setState(() => _logoBase64 = picked);
      } else {
        await _generateMonogramLogo();
      }
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _pickSignatureFromGallery() async {
    if (_pickingSignature) return;
    setState(() => _pickingSignature = true);
    try {
      final picked = await LogoPickerService.pickFromDevice();
      if (!mounted) return;
      if (picked != null && picked.isNotEmpty) {
        setState(() => _signatureBase64 = picked);
      }
    } finally {
      if (mounted) setState(() => _pickingSignature = false);
    }
  }

  Future<void> _pickLetterheadFromGallery() async {
    if (_pickingLetterhead) return;
    setState(() => _pickingLetterhead = true);
    try {
      final picked = await LogoPickerService.pickFromDevice();
      if (!mounted) return;
      if (picked != null && picked.isNotEmpty) {
        setState(() => _letterheadHeaderBase64 = picked);
      }
    } finally {
      if (mounted) setState(() => _pickingLetterhead = false);
    }
  }

  Future<void> _generateMonogramLogo() async {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (widget.organization.name ?? 'My Business');
    final generated = await LogoPickerService.generateBrandMonogramBase64(
      businessName: name,
      primaryColor: _selectedBrandColor,
      customInitials: _monogramInitialsController.text.trim(),
    );
    if (!mounted || generated == null) return;
    setState(() => _logoBase64 = generated);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider.notifier).updateOrganization({
        'name': _nameController.text.trim().isEmpty
            ? (widget.organization.name ?? 'Biashara Yangu')
            : _nameController.text.trim(),
        'taxId': _tinController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'logoBase64': _logoBase64 ?? '',
        'signatureBase64': _signatureBase64 ?? '',
        'letterheadHeaderBase64': _letterheadHeaderBase64 ?? '',
        'hideHeaderForPrePrinted': _hideHeaderForPrePrinted,
        'prePrintedTopMarginMm': _prePrintedTopMarginMm,
        'bankName': _bankNameController.text.trim(),
        'bankAccountName': _bankAccountNameController.text.trim(),
        'bankAccountNumber': _bankAccountNumberController.text.trim(),
        'bankBranchOrSwift': _bankSwiftController.text.trim(),
        'mobileMoneyDetails': _mobileMoneyController.text.trim(),
        'invoiceTerms': _termsController.text.trim(),
        'authorizedSignatoryName': _signatoryNameController.text.trim(),
        'authorizedSignatoryTitle': _signatoryTitleController.text.trim(),
      });

      final tplNotifier = ref.read(documentTemplateControllerProvider.notifier);
      await tplNotifier.switchDocumentType(DocumentType.invoice);
      await tplNotifier.selectTemplate(_selectedLayoutStyle.templateId);
      tplNotifier.updatePrimaryHex(_primaryHex);
      tplNotifier.updateSecondaryHex(_secondaryHex);
      await tplNotifier.saveConfiguration();

      if (!mounted) return;
      final isSw = Localizations.localeOf(context).languageCode == 'sw';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSw
                ? 'Mtindo wa ankara, nembo na sahihi vimehifadhiwa!'
                : 'Invoice template, logo & signature settings saved!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final logoBytes = LogoPickerService.decodeLogoBytes(_logoBase64);
    final signatureBytes = LogoPickerService.decodeLogoBytes(_signatureBase64);
    final letterheadBytes =
        LogoPickerService.decodeLogoBytes(_letterheadHeaderBase64);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSw
                            ? 'Nembo ya Kampuni na Mipangilio ya Ankara'
                            : 'Company Logo & Invoice Setup',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.resolveTextPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 0. TEMPLATE LAYOUT STYLE SECTION
                    _SectionHeader(
                      icon: Icons.dashboard_customize_outlined,
                      title: isSw
                          ? 'Mtindo wa Ankara (Invoice Template Layout)'
                          : 'Invoice Template Layout Style',
                      subtitle: isSw
                          ? 'Chagua muundo wa ankara unaolingana na biashara yako au weka karatasi yako (Letterhead)'
                          : 'Choose a layout archetype or upload your own designer letterhead',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: InvoiceLayoutStyle.values.map((style) {
                        final selected = _selectedLayoutStyle == style;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(
                            style.title(isSw),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedLayoutStyle = style;
                              _primaryHex = style.defaultPrimaryHex;
                              _secondaryHex = style.defaultSecondaryHex;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedLayoutStyle ==
                        InvoiceLayoutStyle.customLetterhead) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.resolveSurfaceSecondary(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.resolveBorder(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isSw
                                    ? 'Ninatumia Karatasi Iliyochapishwa Tayari (Pre-Printed Paper)'
                                    : 'Use Physical Pre-Printed Stationery Paper',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.resolveTextPrimary(context),
                                ),
                              ),
                              subtitle: Text(
                                isSw
                                    ? 'Huacha nafasi wazi juu (${_prePrintedTopMarginMm.round()}mm) ili isigongane na kichwa cha karatasi yako'
                                    : 'Leaves a blank top margin (${_prePrintedTopMarginMm.round()}mm) for your physical letterhead',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      AppColors.resolveTextSecondary(context),
                                ),
                              ),
                              value: _hideHeaderForPrePrinted,
                              onChanged: (v) => setState(
                                  () => _hideHeaderForPrePrinted = v),
                            ),
                            if (_hideHeaderForPrePrinted)
                              Slider(
                                value: _prePrintedTopMarginMm.clamp(20.0, 90.0),
                                min: 20.0,
                                max: 90.0,
                                divisions: 14,
                                label: '${_prePrintedTopMarginMm.round()} mm',
                                onChanged: (v) => setState(
                                    () => _prePrintedTopMarginMm = v),
                              )
                            else ...[
                              if (letterheadBytes != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    letterheadBytes,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickingLetterhead
                                          ? null
                                          : _pickLetterheadFromGallery,
                                      icon: const Icon(
                                          Icons.upload_file_outlined,
                                          size: 18),
                                      label: Text(
                                        isSw
                                            ? 'Pakia Bango la Juu (Letterhead Banner)'
                                            : 'Upload Full-Width Letterhead Banner',
                                      ),
                                    ),
                                  ),
                                  if (letterheadBytes != null)
                                    IconButton(
                                      onPressed: () => setState(() =>
                                          _letterheadHeaderBase64 = null),
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppColors.error),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // 1. LOGO SECTION
                    _SectionHeader(
                      icon: Icons.image_outlined,
                      title: isSw
                          ? '1. Nembo ya Biashara (Company Logo)'
                          : '1. Business Logo',
                      subtitle: isSw
                          ? 'Itaonekana juu ya kila Ankara ya A4 utakayotuma kwa mteja'
                          : 'Printed at the top-left of every A4 Invoice PDF',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.resolveSurfaceSecondary(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.resolveBorder(context),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.resolveBorder(context),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: logoBytes != null
                                    ? Image.memory(
                                        logoBytes,
                                        fit: BoxFit.contain,
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 30,
                                            color: AppColors
                                                .resolveTextSecondary(context),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isSw ? 'Hakuna Nembo' : 'No Logo',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors
                                                  .resolveTextSecondary(
                                                      context),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _pickingLogo
                                          ? null
                                          : _pickLogoFromGallery,
                                      icon: const Icon(
                                          Icons.upload_file_outlined,
                                          size: 18),
                                      label: Text(
                                        isSw
                                            ? 'Chagua Nembo kwenye Simu'
                                            : 'Upload Logo from Device',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _generateMonogramLogo,
                                      icon: const Icon(
                                          Icons.auto_awesome_outlined,
                                          size: 18),
                                      label: Text(
                                        isSw
                                            ? 'Tengeneza Nembo ya Herufi'
                                            : 'Generate Brand Monogram',
                                      ),
                                    ),
                                    if (logoBytes != null) ...[
                                      const SizedBox(height: 4),
                                      TextButton.icon(
                                        onPressed: () =>
                                            setState(() => _logoBase64 = null),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 16, color: AppColors.error),
                                        label: Text(
                                          isSw ? 'Ondoa Nembo' : 'Remove Logo',
                                          style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                isSw ? 'Rangi ya Nembo:' : 'Monogram Color:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.resolveTextSecondary(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    for (final color in _brandPalette)
                                      GestureDetector(
                                        onTap: () {
                                          setState(
                                              () => _selectedBrandColor = color);
                                          _generateMonogramLogo();
                                        },
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  _selectedBrandColor == color
                                                      ? AppColors.primary
                                                      : Colors.transparent,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: _selectedBrandColor == color
                                              ? const Icon(Icons.check,
                                                  size: 14, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. SELLER IDENTITY
                    _SectionHeader(
                      icon: Icons.business_outlined,
                      title: isSw
                          ? '2. Taarifa za Muuzaji (Seller Identity)'
                          : '2. Seller Identity (Header & Footer Info)',
                      subtitle: isSw
                          ? 'Jina rasmi la kampuni, TIN, simu, tovuti (website) na anwani'
                          : 'Legal trading name, TIN, phone, website, email & address',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText:
                            isSw ? 'Jina la Kampuni / Biashara *' : 'Business / Company Name *',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tinController,
                            decoration: InputDecoration(
                              labelText: isSw ? 'Namba ya TIN' : 'TIN Number',
                              hintText: '123-456-789',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: isSw ? 'Simu ya Ofisi' : 'Business Phone',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: isSw ? 'Barua Pepe (Email)' : 'Business Email',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _websiteController,
                            decoration: InputDecoration(
                              labelText: isSw ? 'Tovuti (Website)' : 'Website',
                              hintText: 'www.kampuni.co.tz',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: isSw
                            ? 'Anwani ya Ofisi / Mtaa na Mji'
                            : 'Physical Address (Street, Building, City)',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. PAYMENT INSTRUCTIONS (BANK & MOBILE MONEY)
                    _SectionHeader(
                      icon: Icons.account_balance_outlined,
                      title: isSw
                          ? '3. Maelekezo ya Malipo (Bank & Lipa Namba)'
                          : '3. Payment Instructions (Bank & Mobile Money)',
                      subtitle: isSw
                          ? 'Mteja ataona akaunti hizi chini ya ankara ili alipe kwa urahisi'
                          : 'Displayed on every invoice so clients know how to pay you',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bankNameController,
                            decoration: InputDecoration(
                              labelText: isSw ? 'Jina la Benki' : 'Bank Name',
                              hintText: 'e.g. CRDB Bank / NMB / Stanbic',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _bankSwiftController,
                            decoration: InputDecoration(
                              labelText:
                                  isSw ? 'Tawi au SWIFT' : 'Branch / SWIFT Code',
                              hintText: 'e.g. CORUTZTZ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bankAccountNameController,
                            decoration: InputDecoration(
                              labelText:
                                  isSw ? 'Jina la Akaunti' : 'Account Name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _bankAccountNumberController,
                            decoration: InputDecoration(
                              labelText:
                                  isSw ? 'Namba ya Akaunti' : 'Account Number',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileMoneyController,
                      decoration: InputDecoration(
                        labelText: isSw
                            ? 'Lipa Namba / Simu ya Malipo (M-Pesa / Airtel / Tigo)'
                            : 'Mobile Money / Lipa Till Number',
                        hintText:
                            'e.g. M-Pesa Lipa Namba: 55443322 (Jina la Kampuni)',
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. TERMS, DIGITAL SIGNATURE & AUTHORIZED SIGNATORY
                    _SectionHeader(
                      icon: Icons.draw_outlined,
                      title: isSw
                          ? '4. Sahihi Rasmi (Signature / Stamp) na Masharti'
                          : '4. Digital Signature / Stamp & Default Terms',
                      subtitle: isSw
                          ? 'Pakia picha ya sahihi au mhuri ("Issued by, signature:") na masharti ya ankara'
                          : 'Upload your signature/stamp image ("Issued by, signature:") and terms',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.resolveSurfaceSecondary(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.resolveBorder(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 110,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.resolveBorder(context),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: signatureBytes != null
                                ? Image.memory(
                                    signatureBytes,
                                    fit: BoxFit.contain,
                                  )
                                : Center(
                                    child: Text(
                                      isSw ? 'Hakuna Sahihi' : 'No Signature',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.resolveTextSecondary(
                                            context),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickingSignature
                                      ? null
                                      : _pickSignatureFromGallery,
                                  icon: const Icon(Icons.draw_outlined,
                                      size: 16),
                                  label: Text(
                                    isSw
                                        ? 'Pakia Picha ya Sahihi / Mhuri'
                                        : 'Upload Signature / Stamp',
                                  ),
                                ),
                                if (signatureBytes != null)
                                  TextButton.icon(
                                    onPressed: () => setState(
                                        () => _signatureBase64 = null),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 15, color: AppColors.error),
                                    label: Text(
                                      isSw ? 'Ondoa Sahihi' : 'Remove Signature',
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _signatoryNameController,
                            decoration: InputDecoration(
                              labelText: isSw
                                  ? 'Jina la Mwidhinishaji'
                                  : 'Signatory Full Name',
                              hintText: 'e.g. John M. Doe',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _signatoryTitleController,
                            decoration: InputDecoration(
                              labelText: isSw
                                  ? 'Cheo (Title)'
                                  : 'Role / Title',
                              hintText: 'e.g. Managing Director / Finance',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _termsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isSw
                            ? 'Masharti ya Malipo (Default Terms & Conditions)'
                            : 'Default Terms & Conditions',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: AppColors.resolveBorder(context)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      isSw
                          ? 'Hifadhi Nembo na Mipangilio'
                          : 'Save Logo & Invoice Settings',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.resolveTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
