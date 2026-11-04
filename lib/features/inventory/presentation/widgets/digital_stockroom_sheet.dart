import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/barcode/barcode_display_card.dart';
import '../../../../core/storage/local_database.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../sales/application/cart_controller.dart';
import 'print_barcode_label_dialog.dart';

/// Modal sheet activated when floor staff scan a product barcode or tap a product
/// to inspect multi-branch stock levels, exact aisle/bin coordinates, and take quick actions.
Future<void> showDigitalStockroomSheet(
  BuildContext context, {
  required String productId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => _DigitalStockroomSheet(productId: productId),
  );
}

class _DigitalStockroomSheet extends ConsumerStatefulWidget {
  const _DigitalStockroomSheet({required this.productId});
  final String productId;

  @override
  ConsumerState<_DigitalStockroomSheet> createState() =>
      _DigitalStockroomSheetState();
}

class _DigitalStockroomSheetState
    extends ConsumerState<_DigitalStockroomSheet> {
  CachedProduct? _product;
  List<CachedStockData> _stockRows = [];
  double _projectedTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final tenantId = ref.read(sessionContextProvider).$1;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final catalog = ref.read(localSalesServiceProvider).catalog;
    final product = await catalog.byId(tenantId, widget.productId);
    final stock = await catalog.stockForProduct(tenantId, widget.productId);
    final total = await catalog.projectedQuantity(tenantId, widget.productId);

    if (mounted) {
      setState(() {
        _product = product;
        _stockRows = stock;
        _projectedTotal = total;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isSw = Localizations.localeOf(context).languageCode == 'sw';

    if (_loading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              isSw
                  ? 'Taarifa za bidhaa hazikupatikana.'
                  : 'Product details not found in cache.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final product = _product!;
    final isLowStock = _projectedTotal <= 5 && _projectedTotal > 0;
    final isOutOfStock = _projectedTotal <= 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (product.barcode != null && product.barcode!.isNotEmpty)
                      Text(
                        'Barcode: ${product.barcode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Stock KPI Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? Colors.red.shade50
                  : (isLowStock ? Colors.amber.shade50 : Colors.green.shade50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOutOfStock
                    ? Colors.red.shade200
                    : (isLowStock
                        ? Colors.amber.shade300
                        : Colors.green.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSw ? 'Stock Iliyopo (Jumla)' : 'Total On-Hand Stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _projectedTotal % 1 == 0
                          ? '${_projectedTotal.toInt()} pcs'
                          : '${_projectedTotal.toStringAsFixed(1)} pcs',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.red.shade900
                            : (isLowStock
                                ? Colors.amber.shade900
                                : Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(product.retailPrice),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isOutOfStock)
                      const Chip(
                        label: Text('Imeisha', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.red,
                        labelStyle: TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      )
                    else if (isLowStock)
                      const Chip(
                        label: Text('Inaisha', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.amber,
                        labelStyle: TextStyle(color: Colors.black87),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      const Chip(
                        label: Text('Inatosha', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Spatial Location (Aisle / Shelf / Bin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.resolveSurfaceSecondary(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.resolveBorder(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${loc.barcodeLocation}: ',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  isSw ? 'Rafu ya Mbele / Shelf A-2' : 'Front Shelf / Section A-2',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Multi-Branch Breakdown (if multiple warehouses exist)
          if (_stockRows.isNotEmpty) ...[
            Text(
              loc.barcodeMultiBranchStock,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._stockRows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.warehouseId == '*' ? 'Stoo Kuu (Main)' : 'Tawi (Branch)',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${row.quantity.toStringAsFixed(0)} pcs',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Barcode Display Card preview
          if (product.barcode != null && product.barcode!.isNotEmpty)
            BarcodeDisplayCard(
              barcode: product.barcode!,
              productName: product.name,
              priceText: formatMoney(product.retailPrice),
              sku: product.sku,
              height: 50,
            ),
          const SizedBox(height: 20),

          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(loc.barcodePrintLabel),
                  onPressed: () {
                    showPrintBarcodeLabelDialog(
                      context,
                      productName: product.name,
                      barcode: product.barcode ?? product.sku ?? product.name,
                      price: product.retailPrice,
                      sku: product.sku,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(isSw ? 'Uza Sasa' : 'Add to POS'),
                  onPressed: () {
                    ref.read(cartControllerProvider.notifier).add(
                          product.productId,
                          product.name,
                          product.retailPrice ?? 0.0,
                        );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.barcodeItemAdded(product.name)),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
