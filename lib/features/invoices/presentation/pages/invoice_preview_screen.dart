import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/invoice_providers.dart';
import '../../domain/document_template.dart';
import '../widgets/color_hex_picker.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  const InvoicePreviewScreen({
    super.key,
    required this.documentId,
    this.documentNumber = '',
    this.documentType = DocumentType.invoice,
    this.initialIsThermal = false,
    this.initialThemePrimaryHex = '#0F172A',
  });

  final String documentId;
  final String documentNumber;
  final DocumentType documentType;
  final bool initialIsThermal;
  final String initialThemePrimaryHex;

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  PdfDocument? _pdfDocument;
  PdfPageController? _pdfController;
  Uint8List? _rawPdfBytes;

  bool _isLoading = false;
  bool _isPrinting = false;
  String? _errorMessage;

  late bool _isThermal;
  late String _themePrimaryHex;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _isThermal = widget.initialIsThermal;
    _themePrimaryHex = widget.initialThemePrimaryHex;
    _fetchAndRenderPdf();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pdfController?.dispose();
    _pdfDocument?.close();
    super.dispose();
  }

  void _onColorChanged(String hex) {
    setState(() => _themePrimaryHex = hex);
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

      // Dispose existing controller if already instantiated
      _pdfController?.dispose();
      final controller = PdfPageController(page: 1);

      if (!mounted) return;

      setState(() {
        _rawPdfBytes = pdfBytes;
        _pdfDocument = document;
        _pdfController = controller;
        _isLoading = false;
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
      // Binds downloaded raw invoice bytes directly to native spooler without HTML conversions.
      // If Thermal Receipt (80mm) profile is active, hardcodes PdfPageFormat.roll80 layout parameters.
      await Printing.layoutPdf(
        name: '${widget.documentType.name}-${widget.documentNumber}',
        format: _isThermal ? PdfPageFormat.roll80 : PdfPageFormat.a4,
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hitilafu ya uchapishaji: $e'),
            backgroundColor: const Color(0xFFDC2626),
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
        ? (isSw ? 'Hakiki ya Ankara' : 'Invoice Print Preview')
        : (isSw ? 'Hakiki ya Delivery' : 'Delivery Note Preview');

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              docTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (widget.documentNumber.isNotEmpty)
              Text(
                widget.documentNumber,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_rawPdfBytes == null || _isLoading || _isPrinting)
            ? null
            : _spoolToHardwarePrinter,
        backgroundColor:
            _isThermal ? const Color(0xFF0F172A) : const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        icon: _isPrinting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                _isThermal ? Icons.receipt_long : Icons.print_outlined,
                size: 20,
              ),
        label: Text(
          _isPrinting
              ? (isSw ? 'Inatuma kwenye Printa...' : 'Spooling to Printer...')
              : (_isThermal
                  ? (isSw ? 'Chapisha Risiti (80mm)' : 'Print 80mm Roll')
                  : (isSw ? 'Chapisha Ankara (A4)' : 'Print Document')),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: WaveBackground(
        child: isDesktop
            ? Row(
                children: [
                  // Left Config Sidebar
                  SizedBox(
                    width: 360,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right:
                              BorderSide(color: Color(0xFFE2E8F0), width: 1),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildControls(isSw),
                      ),
                    ),
                  ),
                  // Right Native Canvas Preview
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF1F5F9),
                      child: _buildNativeCanvasPreview(isSw),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  // Collapsible or Compact Controls
                  ExpansionTile(
                    title: Text(
                      isSw
                          ? 'Mipangilio ya Rangi & Format'
                          : 'Color & Format Settings',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildControls(isSw),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF1F5F9),
                      child: _buildNativeCanvasPreview(isSw),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildControls(bool isSw) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Layout Profile Toggle
        Text(
          isSw ? 'Umbizo la Karatasi' : 'Paper Format Profile',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FormatProfileButton(
                icon: Icons.description_outlined,
                title: 'A4 Standard',
                subtitle: 'A4 Paper (Sheet)',
                isSelected: !_isThermal,
                onTap: () => _toggleLayoutProfile(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FormatProfileButton(
                icon: Icons.receipt_long,
                title: '80mm Roll',
                subtitle: 'Thermal POS Hardware',
                isSelected: _isThermal,
                onTap: () => _toggleLayoutProfile(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Live Hex Color Picker
        ColorHexPicker(
          label: isSw ? 'Rangi Kuu ya Chapa' : 'Brand Primary Color',
          subtitle: isSw
              ? 'Inatumiwa kusanidi mistari na vichwa kwenye PDF'
              : 'Applies live styling to PDF headers and separators',
          selectedHex: _themePrimaryHex,
          onColorChanged: _onColorChanged,
        ),
        const SizedBox(height: 20),

        // Info Badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSw
                      ? 'Hakiki hii inatumia PDF binary bila WebView. Inatuma data moja kwa moja kwenye printa bila kugeuza HTML.'
                      : 'Native canvas PDF engine without WebView. Spools raw binary bytes directly to POS printer hardware.',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                  size: 40, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
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
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    // Target width for 80mm roll is ~320px
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
            // Native PdfPageView without webviews
            PdfPageView(
              controller: _pdfController!,
              pageSnapping: false,
            ),
            // Floating page badge
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

class _FormatProfileButton extends StatelessWidget {
  const _FormatProfileButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF334155),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
