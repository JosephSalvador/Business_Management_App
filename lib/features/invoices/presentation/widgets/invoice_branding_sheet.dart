import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/platform/logo_picker_service.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../settings/data/organization_repository.dart';

/// Opens a comprehensive bottom sheet where any business user can:
/// 1. Upload their company logo from phone gallery / file picker
/// 2. Or generate a crisp Brand Monogram Logo in one tap
/// 3. Configure Bank Details, Mobile Money (Lipa Namba), Default Terms, and Authorized Signatory
Future<void> showInvoiceBrandingSheet(
  BuildContext context, {
  required Organization organization,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => InvoiceBrandingSheet(organization: organization),
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
  bool _saving = false;
  bool _pickingLogo = false;
  Color _selectedBrandColor = const Color(0xFF0F2942);

  static const _brandPalette = <Color>[
    Color(0xFF0F2942), // Executive Navy
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
    _nameController = TextEditingController(text: org.name ?? '');
    _tinController = TextEditingController(text: org.taxId ?? '');
    _phoneController = TextEditingController(text: org.phone ?? '');
    _emailController = TextEditingController(text: org.email ?? '');
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
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _tinController,
      _phoneController,
      _emailController,
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
        'address': _addressController.text.trim(),
        'logoBase64': _logoBase64 ?? '',
        'bankName': _bankNameController.text.trim(),
        'bankAccountName': _bankAccountNameController.text.trim(),
        'bankAccountNumber': _bankAccountNumberController.text.trim(),
        'bankBranchOrSwift': _bankSwiftController.text.trim(),
        'mobileMoneyDetails': _mobileMoneyController.text.trim(),
        'invoiceTerms': _termsController.text.trim(),
        'authorizedSignatoryName': _signatoryNameController.text.trim(),
        'authorizedSignatoryTitle': _signatoryTitleController.text.trim(),
      });
      if (!mounted) return;
      final isSw = Localizations.localeOf(context).languageCode == 'sw';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSw
                ? 'Nembo na taarifa za ankara zimehifadhiwa!'
                : 'Business logo & invoice settings saved!',
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
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
                          : '2. Seller Identity (Header Info)',
                      subtitle: isSw
                          ? 'Jina rasmi la kampuni, TIN, simu na anwani'
                          : 'Legal trading name, TIN, phone, email & address',
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
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: isSw ? 'Barua Pepe (Email)' : 'Business Email',
                      ),
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

                    // 4. TERMS & AUTHORIZED SIGNATORY
                    _SectionHeader(
                      icon: Icons.draw_outlined,
                      title: isSw
                          ? '4. Masharti ya Ankara na Sahihi Rasmi'
                          : '4. Default Terms & Authorized Signatory',
                      subtitle: isSw
                          ? 'Jina la mwidhinishaji na masharti yanayochapishwa chini ya A4'
                          : 'Printed at the bottom of the A4 invoice beside the Stamp box',
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
