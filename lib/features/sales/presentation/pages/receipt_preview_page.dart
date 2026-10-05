import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../receipts/data/receipt_repository.dart' show PrintType;
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
  ReceiptPreview? _receipt;
  SaleDto? _sale;
  String? _error;
  bool _printing = false;

  /// Prints made from this screen since it was opened. The server count only
  /// catches up after `recordPrint` lands, so this keeps the watermark honest
  /// for a second print in the same session.
  int _printsThisSession = 0;

  bool get _canPrintBt => Platform.isAndroid;

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
        if (mounted) {
          setState(() => _error = context.loc.saleDetailLoadFailed);
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
          if (_canPrintBt)
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: ReceiptTicketCard(
          receipt: receipt,
          isReprint: _isReprint,
        ),
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

  Future<void> _share() async {
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
