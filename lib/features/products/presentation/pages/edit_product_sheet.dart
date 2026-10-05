import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_routes.dart';
import '../../../../l10n/loc.dart';

class EditProductSheet extends ConsumerStatefulWidget {
  const EditProductSheet({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  ConsumerState<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<EditProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _costPriceCtrl;
  String? _unitId;
  String? _categoryId;
  String? _brandId;
  bool _saving = false;
  bool _loadingCatalog = true;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product['name'] ?? '');
    _skuCtrl = TextEditingController(text: widget.product['sku'] ?? '');
    _barcodeCtrl = TextEditingController(text: widget.product['barcode'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.product['description'] ?? '');
    final cp = widget.product['costPrice'];
    _costPriceCtrl = TextEditingController(
        text: cp != null
            ? (cp is int ? cp.toString() : (cp as double).toString())
            : '');
    _unitId = widget.product['unitOfMeasureId'] as String?;
    _categoryId = widget.product['categoryId'] as String?;
    _brandId = widget.product['brandId'] as String?;
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _descCtrl.dispose();
    _costPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        client.get(ApiRoutes.v1('/categories')),
        client.get(ApiRoutes.v1('/brands')),
        client.get(ApiRoutes.v1('/units')),
      ]);
      if (mounted) {
        setState(() {
          _categories = (results[0].data as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _brands = (results[1].data as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _units = (results[2].data as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _loadingCatalog = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        ApiRoutes.v1('/products/${widget.product['id']}'),
        body: {
          'name': _nameCtrl.text.trim(),
          'sku': _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
          'barcode': _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          'description':
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'unitOfMeasureId': _unitId,
          'categoryId': _categoryId,
          'brandId': _brandId,
          if (_costPriceCtrl.text.trim().isNotEmpty)
            'costPrice': double.tryParse(
                _costPriceCtrl.text.trim().replaceAll(',', '.')),
        },
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.productFormSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.productFormTitleEdit,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: loc.productFormName,
                    hintText: loc.productFormNameHint,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _skuCtrl,
                  decoration: InputDecoration(labelText: loc.productsSKU),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeCtrl,
                  decoration:
                      InputDecoration(labelText: loc.productFormBarcode),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration:
                      InputDecoration(labelText: loc.productsDescription),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _costPriceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: loc.productFormCostPrice,
                    hintText: loc.productFormCostPriceHint,
                  ),
                ),
                if (_loadingCatalog) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _unitId,
                    decoration: InputDecoration(
                      labelText: loc.productFormUnit,
                    ),
                    items: _units
                        .map(
                          (u) => DropdownMenuItem(
                            value: u['id'] as String,
                            child: Text(
                              '${u['name'] ?? ''} (${u['abbreviation'] ?? ''})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _unitId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(
                      labelText: loc.productsCategory,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('-'),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text((c['name'] ?? '') as String),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _brandId,
                    decoration: InputDecoration(
                      labelText: loc.productsBrand,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('-'),
                      ),
                      ..._brands.map(
                        (b) => DropdownMenuItem(
                          value: b['id'] as String,
                          child: Text((b['name'] ?? '') as String),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _brandId = v),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
