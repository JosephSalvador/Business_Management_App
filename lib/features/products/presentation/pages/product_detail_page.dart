import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import 'add_stock_sheet.dart';
import 'edit_product_sheet.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _loading = true;

  int _totalStock = 0;
  int _lowStockCount = 0;
  int _zeroStockCount = 0;

  double _retailPrice = 0;
  double _wholesalePrice = 0;

  String _categoryName = '-';
  String _brandName = '-';
  String _unitName = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final productModel =
          await ref.read(productRepositoryProvider).getById(widget.productId);
      final product = productModel.toJson();

      if (!mounted) return;

      int totalStock = 0;
      int lowStockCount = 0;
      int zeroStockCount = 0;
      try {
        final tenantId = ref.read(sessionContextProvider).$1;
        if (tenantId != null) {
          final quantity = await ref
              .read(localSalesServiceProvider)
              .catalog
              .projectedQuantity(tenantId, widget.productId);
          totalStock = quantity.toInt();
          if (quantity <= 0) {
            zeroStockCount = 1;
          } else if (quantity < 10) {
            lowStockCount = 1;
          }
        }
      } catch (_) {}

      if (!mounted) return;

      double retailPrice = 0;
      double wholesalePrice = 0;
      try {
        final catalogProduct =
            await ref.read(localSalesServiceProvider).catalog.byId(
                  ref.read(sessionContextProvider).$1 ?? 'unknown',
                  widget.productId,
                );
        retailPrice = catalogProduct?.retailPrice ?? 0;
      } catch (_) {}

      if (!mounted) return;

      const categoryName = '-';
      const brandName = '-';
      const unitName = '-';

      if (!mounted) return;

      setState(() {
        _product = product;
        _totalStock = totalStock;
        _lowStockCount = lowStockCount;
        _zeroStockCount = zeroStockCount;
        _retailPrice = retailPrice;
        _wholesalePrice = wholesalePrice;
        _categoryName = categoryName;
        _brandName = brandName;
        _unitName = unitName;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditSheet() async {
    if (_product == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProductSheet(product: _product!),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.productsDetailsTitle),
        actions: [
          if (_product != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEditSheet,
            ),
        ],
      ),
      body: WaveBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _product == null
                ? Center(child: Text(loc.productsNotFound))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStockHeader(),
                        const SizedBox(height: 16),
                        _buildProductInfo(),
                        const SizedBox(height: 16),
                        _buildStockInfo(),
                        const SizedBox(height: 16),
                        _buildPriceInfo(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStockHeader() {
    final loc = context.loc;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            if (_totalStock <= 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loc.productsNoStock,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                '$_totalStock ${loc.productsTotalStock}',
                style: TextStyle(
                  color: AppColors.resolveTextSecondary(context),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.productsDetailsTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _infoRow(loc.productFormName, _product?['name'] ?? '-'),
            _infoRow(loc.productsSKU, _product?['sku'] ?? '-'),
            if ((_product?['description'] as String?)?.isNotEmpty == true)
              _infoRow(
                  loc.productsDescription, _product?['description'] ?? '-'),
            _infoRow(loc.productsCategory, _categoryName),
            _infoRow(loc.productsBrand, _brandName),
            _infoRow(loc.productsUnit, _unitName),
            if (_product?['costPrice'] != null)
              _infoRow(loc.productFormCostPrice,
                  formatMoney((_product?['costPrice'] as num).toDouble())),
            if (_product?['costPrice'] != null && _retailPrice > 0)
              _infoRow(
                'Margin',
                '${(((_retailPrice - (_product?['costPrice'] as num).toDouble()) / _retailPrice) * 100).toStringAsFixed(1)}%',
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.resolveTextSecondary(context),
                  fontSize: 14)),
          Flexible(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo() {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.productsStockHub,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _stockStat(loc.productsTotalStock, '$_totalStock'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _stockStat(loc.productsLowStockCount, '$_lowStockCount'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _stockStat(
                      loc.productsZeroStockCount, '$_zeroStockCount'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _offerAddStock,
                icon: const Icon(Icons.add, size: 18),
                label: Text(loc.productsAddStock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _offerAddStock() async {
    final quantity = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddStockSheet(
        productId: widget.productId,
        productName: (_product?['name'] as String?) ?? '',
      ),
    );
    if (quantity == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${context.loc.productsAddStock}: +$quantity')),
    );
    await _load();
  }

  Widget _stockStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.resolveTextSecondary(context))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPriceInfo() {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.productsPrice,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _priceStat(
                    loc.productsRetailPrice,
                    formatMoney(_retailPrice),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _priceStat(
                    loc.productsWholesalePrice,
                    formatMoney(_wholesalePrice),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.resolveTextSecondary(context))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      ],
    );
  }
}
