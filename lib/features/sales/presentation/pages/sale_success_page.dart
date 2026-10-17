import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../onboarding/application/workspace_controller.dart';
import '../../../receipts/data/receipt_repository.dart' show PrintType;
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
    final printerService = ref.read(receiptPrinterServiceProvider);
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
                      const SizedBox(height: 24),

                      Flexible(
                        child: SingleChildScrollView(
                          child: Card(
                            child: ReceiptTicketCard(
                              receipt: receipt,
                              isReprint: _isReprint,
                              dense: true,
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

    // 2. Android Native APK (Bluetooth SPP)
    if (_canPrintBt) {
      await _printViaBluetooth();
      return;
    }

    // 3. Fallback: Browser without Web Bluetooth (e.g. standard Safari on iPhone)
    _showIosSafariPrintHelpDialog();
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
              'Ili kuchapa kwa Bluetooth ya mkononi:\n'
              '1. Sakinisha kivinjari cha bure cha "Bluefy" kutoka App Store.\n'
              '2. Fungua mfumo wako kupitia Bluefy na utachapa papo hapo kwa Bluetooth.\n\n'
              'Pia unaweza kutuma risiti rasmi ya kidijitali sasa kupitia WhatsApp au PDF.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Funga'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _showShareOptions();
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Shiriki WhatsApp / PDF'),
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
      if (device == null) return;
      address = device.address;
      await printerController.selectPrinter(
          device.address, device.name ?? 'Printer');
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
    final loc = context.loc;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: Text(loc.posShareText),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareAsText();
                },
              ),
              if (_canPrintBt)
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(loc.posPrintReceipt),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _printViaBluetooth();
                  },
                ),
            ],
          ),
        ),
      ),
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
