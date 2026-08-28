import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/di/providers.dart';
import '../../../workspace/application/workspace_controller.dart';
import '../../domain/receipt.dart';
import '../../domain/sale.dart';

/// Receipt preview: a plain-text ticket with copy / save actions. Printing
/// hardware is out of scope for M4; this text is what a printer integration
/// will consume later.
class ReceiptPreviewPage extends ConsumerStatefulWidget {
  const ReceiptPreviewPage({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<ReceiptPreviewPage> createState() =>
      _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends ConsumerState<ReceiptPreviewPage> {
  SaleDto? _sale;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale =
          await ref.read(saleRepositoryProvider).getById(widget.saleId);
      if (mounted) {
        setState(() => _sale = sale);
      }
    } on Exception catch (_) {
      // Offline or not yet synced: serve the provisional local copy.
      final local = await ref
          .read(localSalesServiceProvider)
          .findProvisionalDto(widget.saleId);
      if (mounted) {
        setState(() {
          if (local != null) {
            _sale = local;
          } else {
            _error = 'Imeshindikana kupakia risiti. Jaribu tena.';
          }
        });
      }
    }
  }

  String get _businessName {
    final workspace = ref.read(workspaceControllerProvider);
    return workspace is WorkspaceReady && workspace.selected != null
        ? workspace.selected!.name
        : 'Business OS';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risiti'),
        actions: [
          IconButton(
            tooltip: 'Nakili',
            icon: const Icon(Icons.copy),
            onPressed: _sale == null ? null : _copy,
          ),
          IconButton(
            tooltip: 'Hifadhi',
            icon: const Icon(Icons.save_outlined),
            onPressed: _sale == null ? null : _saveToFile,
          ),
        ],
      ),
      body: switch ((_sale, _error)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (_, final error?) => Center(child: Text(error)),
        (final sale?, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  buildReceiptText(sale: sale, businessName: _businessName),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
      },
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(
      text: buildReceiptText(sale: _sale!, businessName: _businessName),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risiti imenakiliwa.')),
      );
    }
  }

  Future<void> _saveToFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'risiti-${_sale!.number}.txt'));
      await file.writeAsString(
        buildReceiptText(sale: _sale!, businessName: _businessName),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Risiti imehifadhiwa: ${file.path}')),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imeshindikana kuhifadhi risiti.')),
        );
      }
    }
  }
}
