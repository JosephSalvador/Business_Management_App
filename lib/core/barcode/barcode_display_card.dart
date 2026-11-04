import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'barcode_generator_service.dart';

class BarcodeDisplayCard extends StatelessWidget {
  const BarcodeDisplayCard({
    super.key,
    required this.barcode,
    this.productName,
    this.priceText,
    this.sku,
    this.height = 70.0,
    this.width = double.infinity,
    this.showDetails = true,
  });

  final String barcode;
  final String? productName;
  final String? priceText;
  final String? sku;
  final double height;
  final double width;
  final bool showDetails;

  Barcode _resolveBarcodeEngine(String code) {
    final format = BarcodeGeneratorService.detectFormat(code);
    switch (format) {
      case BarcodeFormatKind.ean13:
        if (BarcodeGeneratorService.isValidEan13(code)) {
          return Barcode.ean13();
        }
        return Barcode.code128();
      case BarcodeFormatKind.upcA:
        if (BarcodeGeneratorService.isValidUpcA(code)) {
          return Barcode.upcA();
        }
        return Barcode.code128();
      case BarcodeFormatKind.code128:
      case BarcodeFormatKind.qrCode:
        return Barcode.code128();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (barcode.trim().isEmpty) return const SizedBox.shrink();
    final clean = barcode.trim();
    final engine = _resolveBarcodeEngine(clean);
    final formatKind = BarcodeGeneratorService.detectFormat(clean);

    return InkWell(
      onTap: () => _showFullscreenPreview(context, clean, engine, formatKind),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showDetails && productName != null) ...[
              Text(
                productName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              height: height,
              child: BarcodeWidget(
                barcode: engine,
                data: clean,
                errorBuilder: (context, error) => Center(
                  child: Text(
                    'Invalid: $clean',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                  ),
                ),
                color: Colors.black,
                drawText: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            if (showDetails && (priceText != null || sku != null)) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (sku != null && sku!.isNotEmpty)
                    Text(
                      'SKU: $sku',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    )
                  else
                    const SizedBox.shrink(),
                  if (priceText != null)
                    Text(
                      priceText!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullscreenPreview(
    BuildContext context,
    String code,
    Barcode engine,
    BarcodeFormatKind formatKind,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(formatKind.displayName),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (productName != null) ...[
                Text(
                  productName!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: BarcodeWidget(
                    barcode: engine,
                    data: code,
                    color: Colors.black,
                    drawText: true,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (priceText != null) ...[
                const SizedBox(height: 12),
                Text(
                  priceText!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text('Nakili Barcode ($code)'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Barcode imenakiliwa!')),
                  );
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
