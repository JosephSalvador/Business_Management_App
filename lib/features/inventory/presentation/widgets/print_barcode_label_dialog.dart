import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/barcode_settings_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../data/barcode_label_printer_service.dart';

Future<void> showPrintBarcodeLabelDialog(
  BuildContext context, {
  required String productName,
  required String barcode,
  double? price,
  String? sku,
  String? storeName,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => _PrintBarcodeLabelDialog(
      productName: productName,
      barcode: barcode,
      price: price,
      sku: sku,
      storeName: storeName,
    ),
  );
}

class _PrintBarcodeLabelDialog extends ConsumerStatefulWidget {
  const _PrintBarcodeLabelDialog({
    required this.productName,
    required this.barcode,
    this.price,
    this.sku,
    this.storeName,
  });

  final String productName;
  final String barcode;
  final double? price;
  final String? sku;
  final String? storeName;

  @override
  ConsumerState<_PrintBarcodeLabelDialog> createState() =>
      _PrintBarcodeLabelDialogState();
}

class _PrintBarcodeLabelDialogState
    extends ConsumerState<_PrintBarcodeLabelDialog> {
  late double _widthMm;
  late double _heightMm;
  int _copies = 1;
  bool _asA4Sheet = false;
  bool _printing = false;

  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(barcodeSettingsProvider);
    _widthMm = settings.defaultWidthMm;
    _heightMm = settings.defaultHeightMm;
    _widthCtrl.text = _widthMm.toStringAsFixed(0);
    _heightCtrl.text = _heightMm.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePrint() async {
    if (_printing) return;
    setState(() => _printing = true);

    final service = ref.read(barcodeLabelPrinterServiceProvider);
    final settings = ref.read(barcodeSettingsProvider);

    try {
      await service.printLabel(
        item: LabelPrintItem(
          productName: widget.productName,
          barcode: widget.barcode,
          price: widget.price,
          sku: widget.sku,
          storeName: widget.storeName,
        ),
        widthMm: _widthMm,
        heightMm: _heightMm,
        settings: settings,
        copies: _copies,
        asA4Sheet: _asA4Sheet,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lebo imetumwa kwenye printa!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hitilafu ya uchapishaji: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.barcodePrintLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Sticker Preview Box
              Center(
                child: Container(
                  width: (_widthMm * 4.0).clamp(160.0, 320.0),
                  height: (_heightMm * 4.0).clamp(80.0, 180.0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black87, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.productName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '||||||||| | |||| | ||||||||',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          color: Colors.black.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.barcode,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (widget.price != null)
                            Text(
                              formatMoney(widget.price!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Size Presets & Custom Dimensions
              Text(
                '${loc.barcodeLabelSize} (${_widthMm.toStringAsFixed(0)} × ${_heightMm.toStringAsFixed(0)} mm)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('50 × 30 mm'),
                    selected: _widthMm == 50 && _heightMm == 30 && !_asA4Sheet,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _widthMm = 50;
                          _heightMm = 30;
                          _widthCtrl.text = '50';
                          _heightCtrl.text = '30';
                          _asA4Sheet = false;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('40 × 30 mm'),
                    selected: _widthMm == 40 && _heightMm == 30 && !_asA4Sheet,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _widthMm = 40;
                          _heightMm = 30;
                          _widthCtrl.text = '40';
                          _heightCtrl.text = '30';
                          _asA4Sheet = false;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('30 × 20 mm'),
                    selected: _widthMm == 30 && _heightMm == 20 && !_asA4Sheet,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _widthMm = 30;
                          _heightMm = 20;
                          _widthCtrl.text = '30';
                          _heightCtrl.text = '20';
                          _asA4Sheet = false;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('60 × 40 mm'),
                    selected: _widthMm == 60 && _heightMm == 40 && !_asA4Sheet,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _widthMm = 60;
                          _heightMm = 40;
                          _widthCtrl.text = '60';
                          _heightCtrl.text = '40';
                          _asA4Sheet = false;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('A4 (24 Lebo/Sheet)'),
                    selected: _asA4Sheet,
                    onSelected: (sel) {
                      setState(() => _asA4Sheet = sel);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Custom Width and Height Inputs
              if (!_asA4Sheet)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: loc.barcodeLabelWidth,
                          suffixText: 'mm',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= 15) {
                            setState(() => _widthMm = parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('×',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: loc.barcodeLabelHeight,
                          suffixText: 'mm',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= 10) {
                            setState(() => _heightMm = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Copies Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.barcodeLabelQuantity,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: _copies > 1
                            ? () => setState(() => _copies--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_copies',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => setState(() => _copies++),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Print Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _printing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print),
                  label: Text(_printing
                      ? 'Inachapa...'
                      : (_asA4Sheet
                          ? 'Chapa Karatasi ya A4'
                          : '${loc.barcodePrintLabels} ($_copies)')),
                  onPressed: _printing ? null : _handlePrint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
