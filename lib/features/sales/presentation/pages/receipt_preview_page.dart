import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../core/storage/receipt_customization_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../onboarding/application/workspace_controller.dart';
import '../../../receipts/data/receipt_repository.dart' show PrintType;
import '../../../receipts/domain/receipt_format.dart';
import '../../../receipts/domain/receipt_preview.dart';
import '../../../receipts/presentation/widgets/receipt_ticket_card.dart';
import '../../data/receipt_printer_service.dart';
import '../../domain/sale.dart';

class ReceiptPreviewPage extends ConsumerStatefulWidget {
  const ReceiptPreviewPage({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends ConsumerState<ReceiptPreviewPage> {
  final _receiptCardKey = GlobalKey();
  ReceiptPreview? _receipt;
  SaleDto? _sale;
  String? _error;
  bool _printing = false;

  /// Prints made from this screen since it was opened. The server count only
  /// catches up after `recordPrint` lands, so this keeps the watermark honest
  /// for a second print in the same session.
  int _printsThisSession = 0;

  bool get _canPrintBt => !kIsWeb && Platform.isAndroid;

  bool get _isReprint => ((_receipt?.printCount ?? 0) + _printsThisSession) > 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final receipt =
          await ref.read(receiptRepositoryProvider).getPreview(widget.saleId);
      if (mounted) {
        setState(() => _receipt = receipt);
      }
    } on Exception catch (_) {
      try {
        final sale =
            await ref.read(saleRepositoryProvider).getById(widget.saleId);
        if (mounted) {
          setState(() => _sale = sale);
        }
      } on Exception catch (_) {
        // Fallback: reconstruct from local SQLite sale record if available
        final local = await ref
            .read(localSalesServiceProvider)
            .findProvisionalDto(widget.saleId);
        if (mounted) {
          setState(() {
            if (local != null) {
              _sale = local;
              final printerService = ref.read(receiptPrinterServiceProvider);
              final workspace = ref.read(workspaceControllerProvider);
              final businessName = workspace is WorkspaceReady &&
                      workspace.selected != null
                  ? workspace.selected!.name
                  : 'Business OS';
              _receipt = printerService.saleToReceipt(
                sale: local,
                businessName: businessName,
              );
            } else {
              _error = context.loc.saleDetailLoadFailed;
            }
          });
        }
      }
    }
  }

  String _buildReceiptText() {
    if (_receipt != null) {
      final renderer = ref.read(thermalRendererProvider);
      return renderer.render(receipt: _receipt!, isReprint: _isReprint);
    }
    if (_sale != null) {
      return _sale!.number;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.receiptTitle),
        actions: [
          IconButton(
            tooltip: context.loc.posPrintReceipt,
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
            onPressed: _receipt == null || _printing ? null : _print,
          ),
          IconButton(
            tooltip: context.loc.receiptCopy,
            icon: const Icon(Icons.copy),
            onPressed: _receipt == null ? null : _copy,
          ),
          IconButton(
            tooltip: context.loc.posShare,
            icon: const Icon(Icons.share_outlined),
            onPressed: _receipt == null ? null : _share,
          ),
          IconButton(
            tooltip: context.loc.receiptSave,
            icon: const Icon(Icons.save_outlined),
            onPressed: _receipt == null ? null : _saveToFile,
          ),
        ],
      ),
      body: WaveBackground(
        child: switch ((_receipt, _sale, _error)) {
          (null, null, null) =>
            const Center(child: CircularProgressIndicator()),
          (_, _, final error?) => Center(child: Text(error)),
          (final receipt?, _, _) => _buildReceiptContent(receipt),
          (_, final sale?, _) => _buildLegacyReceiptContent(sale),
        },
      ),
    );
  }

  Widget _buildReceiptContent(ReceiptPreview receipt) {
    final currentWidth = ref.watch(receiptPaperWidthProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<ReceiptPaperWidth>(
              segments: const [
                ButtonSegment(
                  value: ReceiptPaperWidth.mm80,
                  label: Text('80 mm'),
                  icon: Icon(Icons.receipt_long, size: 18),
                ),
                ButtonSegment(
                  value: ReceiptPaperWidth.mm58,
                  label: Text('58 mm'),
                  icon: Icon(Icons.receipt, size: 18),
                ),
              ],
              selected: {currentWidth},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  ref.read(receiptPaperWidthProvider.notifier).state =
                      set.first;
                }
              },
            ),
          ),
          RepaintBoundary(
            key: _receiptCardKey,
            child: Card(
              child: ReceiptTicketCard(
                receipt: receipt,
                isReprint: _isReprint,
                customization: ref.watch(receiptCustomizationProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyReceiptContent(SaleDto sale) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            sale.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _print() async {
    if (_printing || _receipt == null) return;

    final printer = ref.read(receiptPrinterServiceProvider);

    // 1. Web Bluetooth (Bluefy on iOS / Chrome on PC or Android)
    if (kIsWeb && printer.hasWebBluetooth) {
      setState(() => _printing = true);
      final wasReprint = _isReprint;
      try {
        final printed = await printer.printViaWebBluetooth(
          receipt: _receipt!,
          isReprint: wasReprint,
        );
        if (printed) {
          await _recordPrint(_receipt!.saleId, wasReprint);
          if (mounted) setState(() => _printsThisSession++);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.loc.posPrintSuccess),
              ),
            );
          }
          return;
        }
      } catch (_) {
        // Fall back to browser print
      } finally {
        if (mounted) setState(() => _printing = false);
      }
    }

    // 2. Android Native APK (Bluetooth SPP)
    if (_canPrintBt) {
      final printerController = ref.read(printerControllerProvider.notifier);
      final printerState = ref.read(printerControllerProvider);

      String? address = printerState.address;

      if (address == null) {
        if (!mounted) return;
        final device = await FlutterBluetoothPrinter.selectDevice(context);
        if (!mounted || device == null) return;
        address = device.address;
        await printerController.selectPrinter(
            device.address, device.name ?? 'Printer');
        if (!mounted) return;
      }

      setState(() => _printing = true);
      final wasReprint = _isReprint;
      try {
        final printed = await printer.printToDevice(
          address: address,
          receipt: _receipt!,
          isReprint: wasReprint,
        );
        if (printed) {
          await _recordPrint(_receipt!.saleId, wasReprint);
          if (mounted) setState(() => _printsThisSession++);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                printed
                    ? context.loc.posPrintSuccess
                    : context.loc.posPrintFailed,
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _printing = false);
      }
      return;
    }

    // 3. Web Universal Browser Print (Firefox, Safari, Chrome, desktop, AirPrint)
    if (kIsWeb && printer.hasBrowserPrinting) {
      await _printViaBrowser();
      return;
    }

    // 4. Fallback dialog
    _showIosSafariPrintHelpDialog();
  }

  Future<void> _printViaBrowser() async {
    if (_printing || _receipt == null) return;
    final printer = ref.read(receiptPrinterServiceProvider);
    setState(() => _printing = true);
    final wasReprint = _isReprint;
    try {
      final printed = await printer.printViaBrowser(
        receipt: _receipt!,
        isReprint: wasReprint,
      );
      if (printed) {
        await _recordPrint(_receipt!.saleId, wasReprint);
        if (mounted) setState(() => _printsThisSession++);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _showIosSafariPrintHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Uchapishaji wa Risiti'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kwenye iPhone, Safari huzuia Bluetooth ya mkononi moja kwa moja.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Unaweza kuchapa kupitia AirPrint/Kivinjari moja kwa moja, au kutumia kivinjari cha "Bluefy" kuunganisha mashine ya Bluetooth moja kwa moja.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Funga'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _printViaBrowser();
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Chapa Risiti'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _share();
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Shiriki PDF'),
          ),
        ],
      ),
    );
  }

  /// Fire-and-forget audit row — never blocks or fails the print UX. Offline
  /// failures are swallowed: the watermark is a nicety, the audit row is the
  /// goal, and the next successful print records again.
  Future<void> _recordPrint(String saleId, bool wasReprint) async {
    try {
      await ref.read(receiptRepositoryProvider).recordPrint(
            saleId: saleId,
            type: wasReprint ? PrintType.reprint : PrintType.original,
          );
    } on Exception {
      // Deliberately ignored — see doc comment.
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _buildReceiptText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.receiptCopied)),
      );
    }
  }

  void _share() {
    _showShareOptions();
  }

  void _showShareOptions() {
    final isSwahili = Localizations.localeOf(context).languageCode == 'sw';
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isSwahili ? 'Chagua Njia ya Kushiriki' : 'Choose Share Option',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_outlined, color: Colors.green),
                ),
                title: Text(
                  isSwahili ? 'Picha ya Risiti (WhatsApp)' : 'Receipt Image (WhatsApp)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isSwahili
                      ? 'Inatuma picha safi ya risiti kwenye chat'
                      : 'Share as image directly to chats',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareAsImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                ),
                title: Text(
                  isSwahili ? 'Faili la PDF' : 'PDF Document',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isSwahili
                      ? 'Hati rasmi ya PDF ya risiti'
                      : 'Official PDF receipt document',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareAsPdf();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.textsms_outlined, color: Colors.blue),
                ),
                title: Text(
                  isSwahili ? 'Maandishi (SMS / Text)' : 'Text Message (SMS)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isSwahili
                      ? 'Maandishi ya kawaida ya risiti'
                      : 'Plain text receipt message',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareAsText();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAsImage() async {
    try {
      final boundary = _receiptCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _shareAsText();
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _shareAsText();
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final saleNum = _receipt?.saleNumber ?? _sale?.number ?? 'receipt';
      final printerService = ref.read(receiptPrinterServiceProvider);
      await printerService.shareReceiptImage(
        pngBytes: bytes,
        saleNumber: saleNum,
      );
    } catch (_) {
      _shareAsText();
    }
  }

  Future<void> _shareAsPdf() async {
    final printerService = ref.read(receiptPrinterServiceProvider);
    if (_receipt != null) {
      await printerService.shareReceiptPdf(
        receipt: _receipt!,
        isReprint: _isReprint,
      );
    } else {
      _shareAsText();
    }
  }

  Future<void> _shareAsText() async {
    final text = _buildReceiptText();
    await SharePlus.instance.share(
      ShareParams(text: text),
    );
  }

  Future<void> _saveToFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = _receipt?.saleNumber ?? _sale?.number ?? 'unknown';
      final file = File(p.join(dir.path, 'risiti-$fileName.txt'));
      await file.writeAsString(_buildReceiptText());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.receiptSaved(file.path))),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.receiptSaveFailed)),
        );
      }
    }
  }
}
