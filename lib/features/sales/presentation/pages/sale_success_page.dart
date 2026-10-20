import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../core/storage/receipt_customization_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../onboarding/application/workspace_controller.dart';
import '../../../receipts/data/receipt_repository.dart' show PrintType;
import '../../../receipts/domain/receipt_format.dart';
import '../../../receipts/presentation/widgets/receipt_ticket_card.dart';
import '../../data/receipt_printer_service.dart';
import '../../domain/sale.dart';

class SaleSuccessPage extends ConsumerStatefulWidget {
  const SaleSuccessPage({super.key, required this.sale});

  final SaleDto sale;

  @override
  ConsumerState<SaleSuccessPage> createState() => _SaleSuccessPageState();
}

class _SaleSuccessPageState extends ConsumerState<SaleSuccessPage> {
  final _receiptCardKey = GlobalKey();
  bool _printing = false;

  /// Prints made from this screen. Server count starts at 0 for a fresh sale
  /// and `saleToReceipt` does not carry it, so the first print here is the
  /// original and every one after it is a reprint.
  int _printsThisSession = 0;

  bool get _canPrintBt => !kIsWeb && Platform.isAndroid;

  bool get _isReprint => _printsThisSession > 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final sale = widget.sale;
    final printerService = ref.watch(receiptPrinterServiceProvider);
    final receipt = printerService.saleToReceipt(
      sale: sale,
      businessName: _businessName,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: WaveBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.posSaleComplete,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.resolveTextPrimary(context),
                        ),
                      ),
                      if (sale.pendingLocally) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            loc.posOfflineSale,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.onWarningContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      Center(
                        child: SegmentedButton<ReceiptPaperWidth>(
                          segments: const [
                            ButtonSegment(
                              value: ReceiptPaperWidth.mm80,
                              label: Text('80 mm'),
                              icon: Icon(Icons.receipt_long, size: 16),
                            ),
                            ButtonSegment(
                              value: ReceiptPaperWidth.mm58,
                              label: Text('58 mm'),
                              icon: Icon(Icons.receipt, size: 16),
                            ),
                          ],
                          selected: {ref.watch(receiptPaperWidthProvider)},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              ref
                                  .read(receiptPaperWidthProvider.notifier)
                                  .setWidth(set.first);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      Flexible(
                        child: SingleChildScrollView(
                          child: RepaintBoundary(
                            key: _receiptCardKey,
                            child: Card(
                              child: ReceiptTicketCard(
                                receipt: receipt,
                                isReprint: _isReprint,
                                dense: true,
                                customization:
                                    ref.watch(receiptCustomizationProvider),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      FilledButton(
                        onPressed: () => context.go(Routes.pos),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          loc.posSellAgain,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _printing
                          ? const SizedBox(
                              height: 52,
                              child:
                                  Center(child: CircularProgressIndicator()),
                            )
                          : OutlinedButton.icon(
                              onPressed: _printReceipt,
                              icon: const Icon(Icons.print, size: 20),
                              label: Text(loc.posPrintReceipt),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                            ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _showShareOptions,
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: Text(loc.posShare),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _businessName {
    final workspace = ref.read(workspaceControllerProvider);
    return workspace is WorkspaceReady && workspace.selected != null
        ? workspace.selected!.name
        : 'Business OS';
  }

  Future<void> _printReceipt() async {
    if (_printing) return;

    final printer = ref.read(receiptPrinterServiceProvider);

    // 1. Web Bluetooth (Bluefy on iOS / Chrome on PC or Android)
    if (kIsWeb && printer.hasWebBluetooth) {
      setState(() => _printing = true);
      final wasReprint = _isReprint;
      try {
        final receipt = printer.saleToReceipt(
          sale: widget.sale,
          businessName: _businessName,
        );
        final printed = await printer.printViaWebBluetooth(
          receipt: receipt,
          isReprint: wasReprint,
        );
        if (printed) {
          await _recordPrint(widget.sale.id, wasReprint);
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
      await _printViaBluetooth();
      return;
    }

    // 3. Web Universal Browser Print (Firefox, Safari, desktop, AirPrint)
    if (kIsWeb && printer.hasBrowserPrinting) {
      await _printViaBrowser();
      return;
    }

    // 4. Fallback dialog
    _showIosSafariPrintHelpDialog();
  }

  Future<void> _printViaBrowser() async {
    if (_printing) return;
    final printer = ref.read(receiptPrinterServiceProvider);
    setState(() => _printing = true);
    final wasReprint = _isReprint;
    try {
      final receipt = printer.saleToReceipt(
        sale: widget.sale,
        businessName: _businessName,
      );
      final printed = await printer.printViaBrowser(
        receipt: receipt,
        isReprint: wasReprint,
      );
      if (printed) {
        await _recordPrint(widget.sale.id, wasReprint);
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
              'Kwenye iPhone, Safari huzuia Bluetooth moja kwa moja.',
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
              _showShareOptions();
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Shiriki'),
          ),
        ],
      ),
    );
  }

  Future<void> _printViaBluetooth() async {
    if (_printing) return;

    final printerController = ref.read(printerControllerProvider.notifier);
    final printerState = ref.read(printerControllerProvider);

    String? address = printerState.address;

    // If no saved printer, show device selector
    if (address == null) {
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
      final printer = ref.read(receiptPrinterServiceProvider);
      final receipt = printer.saleToReceipt(
        sale: widget.sale,
        businessName: _businessName,
      );
      final printed = await printer.printToDevice(
        address: address,
        receipt: receipt,
        isReprint: wasReprint,
      );
      if (printed) {
        await _recordPrint(widget.sale.id, wasReprint);
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
  }

  /// Fire-and-forget audit row — never blocks or fails the print UX.
  Future<void> _recordPrint(String saleId, bool wasReprint) async {
    try {
      await ref.read(receiptRepositoryProvider).recordPrint(
            saleId: saleId,
            type: wasReprint ? PrintType.reprint : PrintType.original,
          );
    } on Exception {
      // Offline — swallowed; the print already happened.
    }
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
      final printerService = ref.read(receiptPrinterServiceProvider);
      await printerService.shareReceiptImage(
        pngBytes: bytes,
        saleNumber: widget.sale.number,
      );
    } catch (_) {
      _shareAsText();
    }
  }

  Future<void> _shareAsPdf() async {
    final printerService = ref.read(receiptPrinterServiceProvider);
    final receipt = printerService.saleToReceipt(
      sale: widget.sale,
      businessName: _businessName,
    );
    await printerService.shareReceiptPdf(
      receipt: receipt,
      isReprint: _isReprint,
    );
  }

  void _shareAsText() {
    final printerService = ref.read(receiptPrinterServiceProvider);
    final text = printerService.buildReceiptText(
      receipt: printerService.saleToReceipt(
        sale: widget.sale,
        businessName: _businessName,
      ),
      isReprint: _isReprint,
    );
    SharePlus.instance.share(ShareParams(text: text));
  }
}
