import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../../../../core/network/connectivity_monitor.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/responsive_layout_builder.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../sales/data/sales_providers.dart'
    show connectionQualityProvider;
import '../../../settings/data/organization_repository.dart';
import '../../data/invoice_providers.dart';
import '../../domain/document_template.dart';
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
    this.initialIsThermal = false,
    this.initialThemePrimaryHex = '#0F172A',
    this.initialThemeSecondaryHex = '#0D9488',
  });

  final String documentId;
  final String documentNumber;
  final DocumentType documentType;
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
  PdfDocument? _pdfDocument;
  PdfPageController? _pdfController;
  Uint8List? _rawPdfBytes;

  bool _isLoading = false;
  bool _isPrinting = false;
  String? _errorMessage;
  bool _tabletSheetCollapsed = true;

  late bool _isThermal;
  late String _themePrimaryHex;
  late String _themeSecondaryHex;
  bool? _isSynced;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _phoneTabController = TabController(length: 2, vsync: this);
    _isThermal = widget.initialIsThermal;
    _themePrimaryHex = widget.initialThemePrimaryHex;
    _themeSecondaryHex = widget.initialThemeSecondaryHex;
    _fetchAndRenderPdf();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneTabController.dispose();
    _pdfController?.dispose();
    _pdfDocument?.close();
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

    final connectionQuality = ref.read(connectionQualityProvider);
    final isOffline = connectionQuality == ConnectionQuality.offline ||
        connectionQuality == ConnectionQuality.unreachable;

    if (!isOffline) {
      try {
        final repository = ref.read(documentTemplateRepositoryProvider);
        final List<int> bytesList = widget.documentType == DocumentType.invoice
            ? await repository.getInvoicePdfBytes(
                widget.documentId,
                isThermal: _isThermal,
                primaryHex: _themePrimaryHex,
              )
            : await repository.getDeliveryNotePdfBytes(
                widget.documentId,
                isThermal: _isThermal,
                primaryHex: _themePrimaryHex,
              );

        final pdfBytes = Uint8List.fromList(bytesList);

        // Open thread-safe native PdfDocument structure from raw binary
        final document = await PdfDocument.openData(pdfBytes);

        _pdfController?.dispose();
        final controller = PdfPageController(page: 1);

        if (!mounted) return;

        setState(() {
          _rawPdfBytes = pdfBytes;
          _pdfDocument = document;
          _pdfController = controller;
          _isLoading = false;
          _isSynced = true;
        });
        return;
      } catch (_) {
        // Network or server error: smoothly fall through to on-device native PDF compiler
      }
    }

    // ON-DEVICE NATIVE PDF LAYOUT COMPILER (WebView-Free Offline Print Engine)
    try {
      final localCompiler = ref.read(localPdfDocumentGeneratorProvider);
      final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
      Organization? org;
      try {
        org = await ref.read(organizationRepositoryProvider).getOrganization();
      } catch (_) {}

      final Uint8List pdfBytes;
      bool isDocSynced = false;
      if (widget.documentType == DocumentType.invoice) {
        final invoice =
            await ref.read(invoiceRepositoryProvider).getById(widget.documentId);
        isDocSynced = invoice.isSynced;
        pdfBytes = _isThermal
            ? await localCompiler.generateInvoiceThermal80mm(
                invoice: invoice,
                organization: org,
                isSwahili: isSwahili,
              )
            : await localCompiler.generateInvoiceA4(
                invoice: invoice,
                organization: org,
                primaryHex: _themePrimaryHex,
                secondaryHex: _themeSecondaryHex,
                isSwahili: isSwahili,
              );
      } else {
        final note = await ref
            .read(deliveryNoteRepositoryProvider)
            .getById(widget.documentId);
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
      }

      final document = await PdfDocument.openData(pdfBytes);

      _pdfController?.dispose();
      final controller = PdfPageController(page: 1);

      if (!mounted) return;

      setState(() {
        _rawPdfBytes = pdfBytes;
        _pdfDocument = document;
        _pdfController = controller;
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

  Future<void> _spoolToHardwarePrinter() async {
    final bytes = _rawPdfBytes;
    if (bytes == null || bytes.isEmpty || _isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      // Hardware POS Terminal Print Spooling:
      // Direct raw binary byte binding without HTML conversions.
      // If Thermal Receipt (80mm) profile is active, hardcodes PdfPageFormat.roll80.
      await Printing.layoutPdf(
        name: '${widget.documentType.name}-${widget.documentNumber}',
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

  @override
  Widget build(BuildContext context) {
    final isSw = Localizations.localeOf(context).languageCode == 'sw';
    final docTitle = widget.documentType == DocumentType.invoice
        ? (isSw ? 'Hakiki ya Ankara' : 'Customer Invoice Preview')
        : (isSw ? 'Hakiki ya Delivery' : 'Delivery Note Preview');

    return Scaffold(
      appBar: AppBar(
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
            if (widget.documentNumber.isNotEmpty)
              Text(
                widget.documentNumber,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.tertiary,
                ),
              ),
          ],
        ),
        actions: [
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
                          '${widget.documentType.name}-${widget.documentNumber}.pdf',
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
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. SMALL SCREENS (< 768px): TabBar Single Pane Switcher
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPhoneLayout(BuildContext context, bool isSw) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _phoneTabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
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
                child: _buildControls(isSw),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: _buildNativeCanvasPreview(isSw),
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
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
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
                child: _buildNativeCanvasPreview(isSw),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: _buildControls(isSw),
                  ),
                ),
              Row(
                children: [
                  FloatingActionButton.small(
                    onPressed: () => setState(
                        () => _tabletSheetCollapsed = !_tabletSheetCollapsed),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.onSurface,
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
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    right: BorderSide(color: AppColors.outlineVariant, width: 1),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: _buildControls(isSw),
                ),
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: Container(
                color: AppColors.surfaceDim,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
                child: _buildNativeCanvasPreview(isSw),
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

  Widget _buildControls(bool isSw) {
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
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNativeCanvasPreview(bool isSw) {
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.tertiary,
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

    if (_pdfDocument == null || _pdfController == null) {
      return Center(
        child: Text(
          isSw ? 'Hakuna hati iliyopatikana.' : 'No document available.',
          style: const TextStyle(fontFamily: 'Inter', color: AppColors.tertiary),
        ),
      );
    }

    final double targetWidth = _isThermal ? 320 : 640;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: targetWidth,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_isThermal ? 4 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color:
                _isThermal ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            width: _isThermal ? 2.0 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PdfPageView(
              controller: _pdfController!,
              pageSnapping: false,
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isThermal ? '80mm Roll' : 'A4 Sheet',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
