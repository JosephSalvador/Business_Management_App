import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../products/application/products_controller.dart';
import '../../../products/domain/product.dart';

class _PurchaseLineItem {
  final String productId;
  final String productName;
  final String? sku;
  int quantity;
  double unitPrice;
  final TextEditingController priceController;

  _PurchaseLineItem({
    required this.productId,
    required this.productName,
    this.sku,
    this.quantity = 1,
    this.unitPrice = 0.0,
  }) : priceController = TextEditingController(
          text: unitPrice > 0
              ? (unitPrice % 1 == 0
                  ? unitPrice.toInt().toString()
                  : unitPrice.toStringAsFixed(0))
              : '',
        );

  double get subtotal => quantity * unitPrice;

  void dispose() {
    priceController.dispose();
  }
}

class PurchaseFormPage extends ConsumerStatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  ConsumerState<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends ConsumerState<PurchaseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedSupplierId;
  String? _selectedWarehouseId;
  DateTime? _expectedDate;
  bool _showMoreDetails = false;
  bool _saving = false;

  final List<_PurchaseLineItem> _lines = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productsState = ref.read(productsControllerProvider);
      if (productsState is! ProductsLoaded) {
        ref.read(productsControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _grandTotal =>
      _lines.fold<double>(0.0, (sum, line) => sum + line.subtotal);

  int get _totalUnits => _lines.fold<int>(0, (sum, line) => sum + line.quantity);

  void _openProductPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        onProductSelected: (product) {
          setState(() {
            final existingIndex =
                _lines.indexWhere((l) => l.productId == product.id);
            if (existingIndex >= 0) {
              _lines[existingIndex].quantity += 1;
            } else {
              final defaultPrice = product.costPrice ?? 0.0;
              final newLine = _PurchaseLineItem(
                productId: product.id,
                productName: product.name,
                sku: product.sku,
                quantity: 1,
                unitPrice: defaultPrice,
              );
              newLine.priceController.addListener(() {
                final parsed = double.tryParse(newLine.priceController.text);
                if (parsed != null && parsed != newLine.unitPrice) {
                  setState(() {
                    newLine.unitPrice = parsed;
                  });
                }
              });
              _lines.add(newLine);
            }
          });
        },
      ),
    );
  }

  Future<void> _pickExpectedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = context.loc;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.purchasesLinesRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(purchasesControllerProvider.notifier).create({
        'supplierId': _selectedSupplierId,
        'warehouseId': _selectedWarehouseId,
        'reference': _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        'expectedDate': _expectedDate?.toIso8601String(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'lines': _lines.map((l) {
          return {
            'productId': l.productId,
            'quantity': l.quantity,
            'unitPrice': l.unitPrice,
          };
        }).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.purchasesSaved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.commonWithError('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(suppliersProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    // Auto-select default/first warehouse
    warehousesAsync.whenData((warehouses) {
      if (_selectedWarehouseId == null && warehouses.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedWarehouseId == null) {
            setState(() {
              _selectedWarehouseId = warehouses.first['id'] as String;
            });
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.purchasesAdd),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Supplier & Warehouse Card ──────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront_outlined,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Taarifa za Oda',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Supplier Dropdown
                      suppliersAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(loc.commonWithError('$e')),
                        data: (pagedSuppliers) =>
                            DropdownButtonFormField<String>(
                          initialValue: _selectedSupplierId,
                          decoration: InputDecoration(
                            labelText: loc.purchasesSupplier,
                            prefixIcon:
                                const Icon(Icons.business_outlined, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: pagedSuppliers.items
                              .map<DropdownMenuItem<String>>((s) {
                            return DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(
                                s['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedSupplierId = v),
                          validator: (v) =>
                              v == null ? loc.purchasesSupplierRequired : null,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Warehouse Dropdown
                      warehousesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(loc.commonWithError('$e')),
                        data: (warehouses) => DropdownButtonFormField<String>(
                          initialValue: _selectedWarehouseId,
                          decoration: InputDecoration(
                            labelText: loc.purchasesOffice,
                            prefixIcon: const Icon(
                                Icons.warehouse_outlined,
                                size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          items: warehouses.map<DropdownMenuItem<String>>((w) {
                            return DropdownMenuItem(
                              value: w['id'] as String,
                              child: Text(
                                w['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedWarehouseId = v),
                          validator: (v) =>
                              v == null ? loc.purchasesOfficeRequired : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Optional Details Accordion ──────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: theme.colorScheme.surface,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _showMoreDetails,
                    onExpansionChanged: (exp) =>
                        setState(() => _showMoreDetails = exp),
                    leading: Icon(Icons.tune_outlined,
                        color: AppColors.resolveTextSecondary(context)),
                    title: Text(
                      'Maelezo ya Ziada (Hiari)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    childrenPadding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    children: [
                      TextFormField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          labelText: loc.purchasesReference,
                          hintText: 'Mfano: INV-2026-001',
                          prefixIcon: const Icon(Icons.tag, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickExpectedDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tarehe ya Kutarajiwa',
                            prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _expectedDate == null
                                ? 'Chagua tarehe ya kupokea bidhaa'
                                : DateFormat('dd/MM/yyyy')
                                    .format(_expectedDate!),
                            style: TextStyle(
                              color: _expectedDate == null
                                  ? AppColors.resolveTextSecondary(context)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: loc.purchasesNotes,
                          hintText: 'Maelezo yoyote kuhusu ununuzi huu...',
                          prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Products Header ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Bidhaa Zilizoagizwa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lines.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_lines.length}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openProductPicker,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ongeza Bidhaa'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Order Lines or Empty State ─────────────────────────
              if (_lines.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: AppColors.resolveTextSecondary(context)
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.purchasesEmptyLines,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bofya "Ongeza Bidhaa" kuchagua bidhaa unazotaka kuagiza kutoka kwa mtoaji.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.resolveTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _openProductPicker,
                          icon: const Icon(Icons.add),
                          label: const Text('Chagua Bidhaa za Kuagiza'),
                        ),
                      ],
                    ),
                  ),
                ),

              ..._lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                return _OrderLineCard(
                  line: line,
                  onQuantityChanged: (newQty) {
                    setState(() {
                      line.quantity = newQty;
                    });
                  },
                  onDelete: () {
                    setState(() {
                      line.dispose();
                      _lines.removeAt(index);
                    });
                  },
                );
              }),

              const SizedBox(height: 90), // Bottom bar padding
            ],
          ),
        ),
      ),
      bottomNavigationBar: _lines.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_lines.length} bidhaa • $_totalUnits vipande',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.resolveTextSecondary(context),
                              ),
                            ),
                            Text(
                              formatMoney(_grandTotal),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _saving ? 'Inahifadhi...' : 'Hifadhi Oda',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _OrderLineCard extends StatelessWidget {
  const _OrderLineCard({
    required this.line,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  final _PurchaseLineItem line;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Product Name, SKU, and Delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (line.sku != null && line.sku!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SKU: ${line.sku}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.resolveTextSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Quantity Stepper & Unit Price Field
            Row(
              children: [
                // Stepper
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: line.quantity > 1
                            ? () => onQuantityChanged(line.quantity - 1)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${line.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onQuantityChanged(line.quantity + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Unit Price Field
                Expanded(
                  child: TextFormField(
                    controller: line.priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Bei ya Kununua',
                      prefixText: 'TSh ',
                      prefixStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Row 3: Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Jumla Ndogo',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                ),
                Text(
                  formatMoney(line.subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet({required this.onProductSelected});

  final ValueChanged<Product> onProductSelected;

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsState = ref.watch(productsControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.add_shopping_cart,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Chagua Bidhaa ya Kuagiza',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tafuta kwa jina, SKU, au barcode...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: switch (productsState) {
                ProductsLoading() =>
                  const Center(child: CircularProgressIndicator()),
                ProductsFailure(message: final msg) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(msg, textAlign: TextAlign.center),
                    ),
                  ),
                ProductsLoaded(
                  items: final allProducts,
                  stockByProduct: final stockMap
                ) =>
                  Builder(
                    builder: (context) {
                      final filtered = allProducts.where((p) {
                        if (!p.isActive) return false;
                        if (_query.isEmpty) return true;
                        final nameMatch = p.name.toLowerCase().contains(_query);
                        final skuMatch =
                            p.sku?.toLowerCase().contains(_query) ?? false;
                        final barcodeMatch =
                            p.barcode?.toLowerCase().contains(_query) ?? false;
                        return nameMatch || skuMatch || barcodeMatch;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _query.isEmpty
                                      ? 'Hakuna bidhaa zilizosajiliwa'
                                      : 'Hakuna bidhaa inayoendana na "$_query"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final stock = stockMap[product.id] ?? 0.0;
                          final hasCost = product.costPrice != null &&
                              product.costPrice! > 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'SKU: ${product.sku ?? '-'} • Zilizopo: ${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.resolveTextSecondary(context),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hasCost
                                      ? formatMoney(product.costPrice!)
                                      : 'Bila bei',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: hasCost
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gharama',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        AppColors.resolveTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              widget.onProductSelected(product);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${product.name} imeongezwa kwenye oda'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
              },
            ),
          ],
        );
      },
    );
  }
}
