import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../workspace/application/workspace_controller.dart';
import '../../../../core/network/app_exception.dart';
import '../../application/catalog_controller.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';

/// Add / edit a product. Kept deliberately short — only what the first sale
/// needs. The backend remains authoritative for validation and prices.
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.productId});

  final String? productId;

  bool get isEdit => productId != null;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _price = TextEditingController();
  String? _unitId;
  int _productType = ProductType.goods;
  String? _taxCategoryId;
  bool _saving = false;
  String? _error;
  bool _loadedExisting = false;
  bool _loadingExisting = false;

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    if (catalog is CatalogLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (catalog is CatalogFailure) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEdit ? 'Hariri bidhaa' : 'Bidhaa mpya')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(catalog.message),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(catalogControllerProvider.notifier).load(),
                child: const Text('Jaribu tena'),
              ),
            ],
          ),
        ),
      );
    }

    final ready = catalog as CatalogReady;
    if (widget.isEdit && !_loadedExisting && !_loadingExisting) {
      _loadingExisting = true;
      _loadExisting(ready);
    }
    if (widget.isEdit && !_loadedExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final workspace = ref.watch(workspaceControllerProvider);
    final currency = workspace is WorkspaceReady
        ? workspace.selected?.currency ?? ''
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Hariri bidhaa' : 'Bidhaa mpya'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Jina la bidhaa',
                hintText: 'Mfano: Mchele',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Jina linahitajika.'
                      : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _unitId,
              decoration: const InputDecoration(labelText: 'Kipimo'),
              items: ready.units
                  .map((unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text('${unit.name} (${unit.abbreviation})'),
                      ))
                  .toList(),
              validator: (value) =>
                  value == null ? 'Chagua kipimo.' : null,
              onChanged: (value) => setState(() => _unitId = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Bei ya kuuza',
                prefixText: currency.isEmpty ? null : '$currency ',
              ),
              validator: (value) {
                final parsed =
                    double.tryParse(value?.trim().replaceAll(',', '.') ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Weka bei sahihi (zaidi ya sifuri).';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _taxCategoryId,
              decoration: const InputDecoration(labelText: 'Kodi'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Hakuna'),
                ),
                ...ready.taxCategories.map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _taxCategoryId = value),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: ProductType.goods, label: Text('Bidhaa')),
                ButtonSegment(value: ProductType.service, label: Text('Huduma')),
              ],
              selected: {_productType},
              onSelectionChanged: (selection) =>
                  setState(() => _productType = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sku,
              decoration: const InputDecoration(
                labelText: 'SKU / Barcode',
                hintText: 'Hiari',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEdit ? 'Hifadhi mabadiliko' : 'Hifadhi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadExisting(CatalogReady ready) async {
    try {
      final repository = ref.read(productRepositoryProvider);
      final product = await repository.getById(widget.productId!);
      double? price;
      final priceList = await repository.defaultPriceList();
      if (priceList != null) {
        final rows = await repository.prices(priceList.id);
        price = rows
            .where((row) =>
                row.productId == product.id && row.priceType == 0)
            .map((row) => row.price)
            .firstOrNull;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _name.text = product.name;
        _sku.text = product.sku ?? '';
        _barcode.text = product.barcode ?? '';
        _unitId =
            ready.units.any((u) => u.id == product.unitOfMeasureId)
                ? product.unitOfMeasureId
                : ready.units.firstOrNull?.id;
        _productType = product.productType;
        _taxCategoryId = product.taxCategoryId;
        if (price != null) {
          _price.text = price % 1 == 0
              ? price.toStringAsFixed(0)
              : price.toStringAsFixed(2);
        }
        _loadedExisting = true;
      });
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final draft = ProductDraft(
      name: _name.text.trim(),
      unitOfMeasureId: _unitId!,
      productType: _productType,
      sku: Product.hasText(_sku.text) ? _sku.text.trim() : null,
      barcode: Product.hasText(_barcode.text) ? _barcode.text.trim() : null,
      taxCategoryId: _taxCategoryId,
    );
    final sellingPrice =
        double.tryParse(_price.text.trim().replaceAll(',', '.'));

    try {
      if (widget.isEdit) {
        await ref
            .read(productsControllerProvider.notifier)
            .update(widget.productId!, draft, sellingPrice);
        if (mounted) {
          context.pop();
        }
        return;
      }

      final created = await ref
          .read(productsControllerProvider.notifier)
          .create(draft, sellingPrice);
      if (!mounted) {
        return;
      }
      // Replace the form with the list; the caller offers opening stock.
      context.pop(created);
    } on ConflictException {
      setState(() {
        _saving = false;
        _error = 'Bidhaa yenye SKU au Barcode hii ipo tayari.';
      });
    } on ValidationException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } on ForbiddenException {
      setState(() {
        _saving = false;
        _error = 'Hauna kibali cha kubadilisha bidhaa.';
      });
    } on NetworkException {
      setState(() {
        _saving = false;
        _error = 'Hakuna mtandao. Angalia muunganisho kisha jaribu tena.';
      });
    } on AppException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}
