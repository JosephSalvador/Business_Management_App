import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../app/router.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/responsive_layout_builder.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/data/organization_providers.dart';
import '../../../settings/data/organization_repository.dart';
import '../../application/delivery_notes_controller.dart';
import '../../application/document_template_controller.dart';
import '../../data/invoice_providers.dart';
import '../../domain/delivery_note.dart';
import '../../domain/document_template.dart';
import '../../domain/invoice.dart';
import '../services/local_pdf_document_generator.dart';
import '../widgets/commercial_palette_picker.dart';
import '../widgets/print_profile_selector.dart';
import '../widgets/uniform_command_bar.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.documentId,
    this.documentNumber = '',
    this.documentType = DocumentType.invoice,
    this.initialInvoice,
    this.initialDeliveryNote,
    this.initialIsThermal = false,
    this.initialThemePrimaryHex = '#0F172A',
    this.initialThemeSecondaryHex = '#0D9488',
  });

  final String documentId;
  final String documentNumber;
  final DocumentType documentType;
  final CustomerInvoice? initialInvoice;
  final DeliveryNote? initialDeliveryNote;
  final bool initialIsThermal;
  final String initialThemePrimaryHex;
  final String initialThemeSecondaryHex;

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _phoneTabController;
  Uint8List? _rawPdfBytes;

  bool _isLoading = false;
  bool _isPrinting = false;
  String? _errorMessage;
  bool _tabletSheetCollapsed = true;

  late bool _isThermal;
  late String _themePrimaryHex;
  late String _themeSecondaryHex;
  InvoiceLayoutStyle _selectedLayoutStyle = InvoiceLayoutStyle.modernRibbon;
  bool _showLogo = true;
  String? _customFooterNotes;
  bool? _isSynced;
  DeliveryNote? _currentDeliveryNote;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _phoneTabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _isThermal = widget.initialIsThermal;
    _themePrimaryHex = widget.initialThemePrimaryHex;
    _themeSecondaryHex = widget.initialThemeSecondaryHex;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(documentTemplateControllerProvider.notifier).ensureLoaded();
        if (!mounted) return;
        final cfg =
            ref.read(documentTemplateControllerProvider).currentInvoiceConfiguration;
        setState(() {
          _selectedLayoutStyle = cfg.layoutStyle;
          _themePrimaryHex = cfg.themePrimaryHex ?? _themePrimaryHex;
          _themeSecondaryHex = cfg.themeSecondaryHex ?? _themeSecondaryHex;
          _showLogo = cfg.showLogo;
          _customFooterNotes = cfg.footerNotes;
        });
      } catch (_) {}
      if (mounted) _fetchAndRenderPdf();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneTabController.dispose();
    super.dispose();
  }

  void _onPrimaryColorChanged(String hex) {
    setState(() => _themePrimaryHex = hex);
    _debounceFetch();
  }

  void _onSecondaryColorChanged(String hex) {
    setState(() => _themeSecondaryHex = hex);
    _debounceFetch();
  }

  void _onLayoutStyleChanged(InvoiceLayoutStyle style) {
    setState(() {
      _selectedLayoutStyle = style;
      _themePrimaryHex = style.defaultPrimaryHex;
      _themeSecondaryHex = style.defaultSecondaryHex;
    });
    _debounceFetch();
  }

  void _debounceFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchAndRenderPdf();
    });
  }

  void _toggleLayoutProfile(bool isThermal) {
    if (_isThermal == isThermal) return;
    setState(() => _isThermal = isThermal);
    _fetchAndRenderPdf();
  }

  Future<void> _fetchAndRenderPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final localCompiler = ref.read(localPdfDocumentGeneratorProvider);
      final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
      Organization? org;
      try {
        org = await ref.read(organizationRepositoryProvider).get();
      } catch (_) {}

      final Uint8List pdfBytes;
      bool isDocSynced = false;
      if (widget.documentType == DocumentType.invoice) {
        CustomerInvoice invoice;
        try {
          invoice = await ref
              .read(invoiceRepositoryProvider)
              .getById(widget.documentId);
        } catch (_) {
          if (widget.initialInvoice != null) {
            invoice = widget.initialInvoice!;
          } else {
            rethrow;
          }
        }
        isDocSynced = invoice.isSynced;
        final activeConfig = TenantDocumentConfiguration(
          documentType: DocumentType.invoice,
          activeTemplateId: _selectedLayoutStyle.templateId,
          activeTemplateName: _selectedLayoutStyle.titleEn,
          themePrimaryHex: _themePrimaryHex,
          themeSecondaryHex: _themeSecondaryHex,
          showLogo: _showLogo,
          footerNotes: _customFooterNotes,
        );
        pdfBytes = _isThermal
            ? await localCompiler.generateInvoiceThermal80mm(
                invoice: invoice,
                organization: org,
                isSwahili: isSwahili,
              )
            : await localCompiler.generateInvoiceA4(
                invoice: invoice,
                organization: org,
                templateConfig: activeConfig,
                primaryHex: _themePrimaryHex,
                secondaryHex: _themeSecondaryHex,
                isSwahili: isSwahili,
              );
      } else {
        DeliveryNote? note;
        try {
          note = await ref
              .read(deliveryNoteRepositoryProvider)
              .getById(widget.documentId);
        } catch (_) {
          if (widget.initialDeliveryNote != null) {
            note = widget.initialDeliveryNote!;
          } else {
            rethrow;
          }
        }
        isDocSynced = note.isSynced;
        pdfBytes = _isThermal
            ? await localCompiler.generateDeliveryNoteThermal80mm(
                note: note,
                organization: org,
                isSwahili: isSwahili,
              )
            : await localCompiler.generateDeliveryNoteA4(
                note: note,
                organization: org,
                primaryHex: _themePrimaryHex,
                secondaryHex: _themeSecondaryHex,
                isSwahili: isSwahili,
              );
        if (mounted) {
          _currentDeliveryNote = note;
        }
      }

      if (!mounted) return;

      setState(() {
        _rawPdfBytes = pdfBytes;
        _isLoading = false;
        _isSynced = isDocSynced;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _effectiveDocNumber(BuildContext context) {
    if (widget.documentType == DocumentType.deliveryNote) {
      if (widget.initialDeliveryNote != null) {
        return widget.initialDeliveryNote!.number;
      }
      return widget.documentNumber;
    }
    if (widget.initialInvoice != null) {
      final org = ref.watch(settingsControllerProvider);
      final tplConfig =
          ref.watch(documentTemplateControllerProvider).currentInvoiceConfiguration;
      final orgPrefix =
          org is SettingsLoaded ? org.organization.invoicePrefix : null;
      final prefix = (orgPrefix != null && orgPrefix.trim().isNotEmpty)
          ? orgPrefix
          : tplConfig.invoicePrefix;
      return widget.initialInvoice!.displayNumber(prefix);
    }
    return widget.documentNumber;
  }

  Future<void> _spoolToHardwarePrinter() async {
    final bytes = _rawPdfBytes;
    if (bytes == null || bytes.isEmpty || _isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      // Hardware POS Terminal Print Spooling:
      // Direct raw binary byte binding without HTML conversions.
      // If Thermal Receipt (80mm) profile is active, hardcodes PdfPageFormat.roll80.
      final docNum = _effectiveDocNumber(context);
      await Printing.layoutPdf(
        name: '${widget.documentType.name}-$docNum',
        format: _isThermal ? PdfPageFormat.roll80 : PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hitilafu ya printa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _showDispatchDialog() async {
    final note = _currentDeliveryNote;
    if (note == null) return;
    final isSwahili = Localizations.localeOf(context).languageCode == 'sw';

    final hasAssignedTransport =
        (note.driverName?.trim().isNotEmpty ?? false) ||
            (note.vehicleNumber?.trim().isNotEmpty ?? false);

    if (hasAssignedTransport) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: Color(0xFF0D9488), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili
                          ? 'Thibitisha Usafirishaji'
                          : 'Confirm Dispatch',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      note.number,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSwahili
                    ? 'Mzigo uko tayari kusafirishwa na maelezo yafuatayo:'
                    : 'Dispatch this shipment with existing transport details:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.resolveBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.driverName?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.person,
                                size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${isSwahili ? "Dereva" : "Driver"}: ${note.driverName}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (note.driverPhone?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${isSwahili ? "Simu" : "Phone"}: ${note.driverPhone}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (note.vehicleNumber?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car,
                                size: 16, color: Color(0xFF0D9488)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${isSwahili ? "Chombo / Gari" : "Vehicle"}: ${note.vehicleNumber}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                isSwahili ? 'Badilisha Taarifa' : 'Edit Details',
                style:
                    TextStyle(color: AppColors.resolveTextSecondary(context)),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.local_shipping, size: 18),
              label: Text(
                isSwahili ? 'Safirisha Sasa' : 'Dispatch Now',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(deliveryNotesControllerProvider.notifier).dispatch(
                note.id,
                carrierName: note.carrierName,
                trackingNumber: note.trackingNumber,
                vehicleNumber: note.vehicleNumber,
                driverName: note.driverName,
                driverPhone: note.driverPhone,
              );
          _fetchAndRenderPdf();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isSwahili
                      ? 'Mzigo umethibitishwa kusafirishwa!'
                      : 'Delivery note marked as dispatched!',
                ),
                backgroundColor: const Color(0xFF0D9488),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hitilafu: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
        return;
      } else if (confirm == null) {
        return;
      }
    }

    final driverController = TextEditingController(text: note.driverName ?? '');
    final phoneController = TextEditingController(text: note.driverPhone ?? '');
    final vehicleController = TextEditingController(text: note.vehicleNumber ?? '');
    final carrierController = TextEditingController(text: note.carrierName ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0D9488), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSwahili ? 'Safirisha Mzigo' : 'Dispatch Delivery Note',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    note.number,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolveTextSecondary(context),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: driverController,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Jina la Dereva' : 'Driver Name',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Namba ya Simu ya Dereva' : 'Driver Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleController,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Namba ya Chombo / Gari' : 'Vehicle Plate / Reg No',
                  prefixIcon: const Icon(Icons.directions_car_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carrierController,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Kampuni ya Usafirishaji (Si lazima)' : 'Carrier / Transporter (Optional)',
                  prefixIcon: const Icon(Icons.business_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(isSwahili ? 'Ghairi' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(deliveryNotesControllerProvider.notifier).dispatch(
                  note.id,
                  driverName: driverController.text.trim().isEmpty ? null : driverController.text.trim(),
                  driverPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  vehicleNumber: vehicleController.text.trim().isEmpty ? null : vehicleController.text.trim(),
                  carrierName: carrierController.text.trim().isEmpty ? null : carrierController.text.trim(),
                );
                _fetchAndRenderPdf();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSwahili
                            ? 'Mzigo umethibitishwa kusafirishwa!'
                            : 'Delivery note marked as dispatched!',
                      ),
                      backgroundColor: const Color(0xFF0D9488),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hitilafu: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: Text(isSwahili ? 'Thibitisha Kusafirisha' : 'Confirm Dispatch'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeliverDialog() async {
    final note = _currentDeliveryNote;
    if (note == null) return;
    final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
    final recipientController = TextEditingController(text: note.customerName);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSwahili ? 'Thibitisha Kupokelewa' : 'Confirm Delivery',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    note.number,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolveTextSecondary(context),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSwahili
                  ? 'Mzigo huu umewasilishwa kwa mteja salama? Weka jina la aliyepokea mzigo.'
                  : 'Has this consignment been successfully handed over? Enter recipient name.',
              style: TextStyle(fontSize: 13, color: AppColors.resolveTextSecondary(context)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: recipientController,
              decoration: InputDecoration(
                labelText: isSwahili ? 'Jina la Mpokeaji' : 'Recipient Name',
                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(isSwahili ? 'Ghairi' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(deliveryNotesControllerProvider.notifier).deliver(
                  note.id,
                  recipientName: recipientController.text.trim().isEmpty ? null : recipientController.text.trim(),
                );
                _fetchAndRenderPdf();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSwahili
                            ? 'Mzigo umethibitishwa kupokelewa kikamilifu!'
                            : 'Delivery completed successfully!',
                      ),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hitilafu: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 16),
            label: Text(isSwahili ? 'Thibitisha Kupokea' : 'Confirm Received'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final docTitle = widget.documentType == DocumentType.invoice
        ? (isSw ? 'Hakiki ya Ankara' : 'Customer Invoice Preview')
        : (isSw ? 'Hakiki ya Delivery' : 'Delivery Note Preview');
    final effectiveNumber = _effectiveDocNumber(context);

    void navigateBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.invoices);
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        navigateBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: isSw ? 'Rudi' : 'Back',
            onPressed: navigateBack,
          ),
          title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              docTitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (effectiveNumber.isNotEmpty)
              Text(
                effectiveNumber,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.tertiary,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.documentType == DocumentType.deliveryNote &&
              _currentDeliveryNote != null) ...[
            if (_currentDeliveryNote!.status == DeliveryNoteStatus.draft)
              FilledButton.icon(
                onPressed: _showDispatchDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.local_shipping_outlined, size: 14),
                label: Text(
                  isSw ? 'Safirisha' : 'Dispatch',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              )
            else if (_currentDeliveryNote!.status == DeliveryNoteStatus.dispatched)
              FilledButton.icon(
                onPressed: _showDeliverDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: Text(
                  isSw ? 'Imefika' : 'Delivered',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isSw ? 'Pakia upya' : 'Refresh',
            onPressed: _isLoading ? null : _fetchAndRenderPdf,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: isSw ? 'Shiriki PDF' : 'Share PDF',
            onPressed: _rawPdfBytes == null
                ? null
                : () async {
                    await Printing.sharePdf(
                      bytes: _rawPdfBytes!,
                      filename:
                          '${widget.documentType.name}-$effectiveNumber.pdf',
                    );
                  },
          ),
        ],
      ),
      body: WaveBackground(
        child: ResponsiveLayoutBuilder(
          builder: (context, constraints, category) {
            switch (category) {
              case EnterpriseScreenCategory.phone:
                return _buildPhoneLayout(context, isSw);
              case EnterpriseScreenCategory.tablet:
                return _buildTabletLayout(context, isSw, constraints);
              case EnterpriseScreenCategory.desktop:
                return _buildDesktopLayout(context, isSw, constraints);
            }
          },
        ),
      ),
    ),
  );
}

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SMALL SCREENS (< 768px): TabBar Single Pane Switcher
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPhoneLayout(BuildContext context, bool isSw) {
    return Column(
      children: [
        Container(
          color: AppColors.resolveCardBackground(context),
          child: TabBar(
            controller: _phoneTabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.resolveTextSecondary(context),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: const Icon(Icons.tune_outlined, size: 18),
                text: isSw ? 'Mipangilio' : 'Parameters',
              ),
              Tab(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                text: isSw ? 'Hakiki ya PDF' : 'PDF Canvas',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _phoneTabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildControls(context, isSw),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildNativeCanvasPreview(context, isSw),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: UniformCommandBar(
            isPrinting: _isPrinting,
            isSaving: false,
            isThermal: _isThermal,
            saveSuccess: false,
            isSwahili: isSw,
            isSynced: _isSynced,
            onPrint: _spoolToHardwarePrinter,
            onSave: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. MEDIUM SCREENS (768px - 1023px): Stacked Grid & Collapsible Sheet
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(
      BuildContext context, bool isSw, BoxConstraints constraints) {
    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.resolveCardBackground(context),
                border: Border(
                  bottom: BorderSide(color: AppColors.resolveBorder(context)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PrintProfileSelector(
                      selectedProfile: _isThermal
                          ? PrintSizeProfile.thermal80mm
                          : PrintSizeProfile.a4Standard,
                      onChanged: (p) => _toggleLayoutProfile(p.isThermal),
                      isSwahili: isSw,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: _buildNativeCanvasPreview(context, isSw),
              ),
            ),
          ],
        ),

        // Persistent collapsible bottom sheet
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_tabletSheetCollapsed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: AppColors.resolveCardBackground(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.35
                              : 0.12,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    border: Border.all(color: AppColors.resolveBorder(context)),
                  ),
                  child: SingleChildScrollView(
                    child: _buildControls(context, isSw),
                  ),
                ),
              Row(
                children: [
                  FloatingActionButton.small(
                    onPressed: () => setState(
                        () => _tabletSheetCollapsed = !_tabletSheetCollapsed),
                    backgroundColor: AppColors.resolveCardBackground(context),
                    foregroundColor: AppColors.resolveTextPrimary(context),
                    elevation: 2,
                    child: Icon(
                      _tabletSheetCollapsed
                          ? Icons.tune_outlined
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UniformCommandBar(
                      isPrinting: _isPrinting,
                      isSaving: false,
                      isThermal: _isThermal,
                      saveSuccess: false,
                      isSwahili: isSw,
                      isSynced: _isSynced,
                      onPrint: _spoolToHardwarePrinter,
                      onSave: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. LARGE SCREENS (>= 1024px): 35% Left Controls / 65% Viewport-Locked Canvas
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(
      BuildContext context, bool isSw, BoxConstraints constraints) {
    final leftWidth = constraints.maxWidth * 0.35;
    final rightWidth = constraints.maxWidth * 0.65;

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.resolveCardBackground(context),
                  border: Border(
                    right: BorderSide(color: AppColors.resolveBorder(context), width: 1),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: _buildControls(context, isSw),
                ),
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: Container(
                color: AppColors.resolveSurfaceSecondary(context),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
                child: _buildNativeCanvasPreview(context, isSw),
              ),
            ),
          ],
        ),
        Positioned(
          left: leftWidth + 24,
          right: 24,
          bottom: 16,
          child: UniformCommandBar(
            isPrinting: _isPrinting,
            isSaving: false,
            isThermal: _isThermal,
            saveSuccess: false,
            isSwahili: isSw,
            isSynced: _isSynced,
            onPrint: _spoolToHardwarePrinter,
            onSave: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, bool isSw) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrintProfileSelector(
          selectedProfile: _isThermal
              ? PrintSizeProfile.thermal80mm
              : PrintSizeProfile.a4Standard,
          onChanged: (profile) => _toggleLayoutProfile(profile.isThermal),
          isSwahili: isSw,
        ),
        if (!_isThermal && widget.documentType == DocumentType.invoice) ...[
          const SizedBox(height: 18),
          Text(
            isSw ? 'Mtindo wa Ankara (Template Style)' : 'Invoice Template Style',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.resolveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
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
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onSelected: (_) => _onLayoutStyleChanged(style),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        CommercialPalettePicker(
          primaryHex: _themePrimaryHex,
          secondaryHex: _themeSecondaryHex,
          onPrimaryChanged: _onPrimaryColorChanged,
          onSecondaryChanged: _onSecondaryColorChanged,
          isSwahili: isSw,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSw
                      ? 'Hakiki hii inatumia GPU Canvas natively bila WebViews, inatuma binary data moja kwa moja kwenye spooler.'
                      : 'Native GPU canvas binary PDF preview. Spools directly to POS terminal hardware without WebViews.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: isDark
                        ? AppColors.resolveTextPrimary(context)
                        : AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNativeCanvasPreview(BuildContext context, bool isSw) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              isSw
                  ? 'Inazalisha PDF binary...'
                  : 'Compiling native PDF binary stream...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchAndRenderPdf,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(isSw ? 'Jaribu Tena' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_rawPdfBytes == null) {
      return Center(
        child: Text(
          isSw ? 'Hakuna hati iliyopatikana.' : 'No document available.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.resolveTextSecondary(context),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: PdfPreview(
        key: ValueKey('${_rawPdfBytes.hashCode}_$_isThermal'),
        build: (format) async => _rawPdfBytes!,
        useActions: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: _isThermal ? 360 : 720,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        scrollViewDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        ),
        loadingWidget: const Center(
          child: CircularProgressIndicator(),
        ),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              error.toString(),
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
