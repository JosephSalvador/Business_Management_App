import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../onboarding/application/workspace_controller.dart';
import '../../../../core/network/app_exception.dart';
import '../../application/catalog_controller.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';

/// Add / edit a product. The core form stays deliberately short — only what
/// the first sale needs. Optional catalog detail (category, brand, wholesale
/// price, identifiers, description) lives behind a collapsed section so it
/// never slows down the everyday seller. Tax is hidden until the TRA add-on.
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
  final _price = TextEditingController();
  final _costPrice = TextEditingController();
  final _wholesalePrice = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  String? _unitId;
  String? _categoryId;
  String? _brandId;
  int _productType = ProductType.goods;
  String? _taxCategoryId;
  bool _saving = false;
  String? _error;
  bool _loadedExisting = false;
  bool _loadingExisting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(catalogControllerProvider) is CatalogLoading) {
        ref.read(catalogControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _costPrice.dispose();
    _wholesalePrice.dispose();
    _sku.dispose();
    _barcode.dispose();
    _description.dispose();
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
        appBar: AppBar(
          title: Text(
            widget.isEdit
                ? context.loc.productFormTitleEdit
                : context.loc.productFormTitleNew,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(catalog.message),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(catalogControllerProvider.notifier).load(),
                child: Text(context.loc.commonRetry),
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
    final currency =
        workspace is WorkspaceReady ? workspace.selected?.currency ?? '' : '';
    final canSetPrice = ref.watch(fullBillingAccessProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? context.loc.productFormTitleEdit
              : context.loc.productFormTitleNew,
        ),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.loc.productFormName,
                  hintText: context.loc.productFormNameHint,
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.loc.productFormNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                enabled: canSetPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: canSetPrice
                      ? context.loc.productFormPrice
                      : context.loc.billingPriceLocked,
                  prefixText: currency.isEmpty ? null : '$currency ',
                ),
                validator: (value) {
                  if (!canSetPrice) return null;
                  final parsed = double.tryParse(
                    value?.trim().replaceAll(',', '.') ?? '',
                  );
                  if (parsed == null || parsed <= 0) {
                    return context.loc.productFormPriceRequired;
                  }
                  return null;
                },
              ),
              if (!canSetPrice) ...[
                const SizedBox(height: 8),
                Text(
                  context.loc.billingPriceLockedMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.loc.productFormCostPrice,
                  prefixText: currency.isEmpty ? null : '$currency ',
                  hintText: context.loc.productFormCostPriceHint,
                  helperText: context.loc.productFormCostPriceGuidance,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.price_change_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed < 0) {
                    return context.loc.productFormCostPriceInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _unitId,
                decoration: InputDecoration(
                  labelText: context.loc.productFormUnit,
                ),
                items: ready.units
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit.id,
                        child: Text('${unit.name} (${unit.abbreviation})'),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? context.loc.productFormUnitRequired : null,
                onChanged: (value) => setState(() => _unitId = value),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: ProductType.goods,
                    label: Text(context.loc.productFormGoods),
                  ),
                  ButtonSegment(
                    value: ProductType.service,
                    label: Text(context.loc.productFormService),
                  ),
                ],
                selected: {_productType},
                onSelectionChanged: (selection) =>
                    setState(() => _productType = selection.first),
              ),
              const SizedBox(height: 8),
              _buildAdvancedSection(currency, ready, canSetPrice),
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
                    : Text(
                        widget.isEdit
                            ? context.loc.productFormSaveEdit
                            : context.loc.productFormSave,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(
    String currency,
    CatalogReady ready,
    bool canSetPrice,
  ) {
    return ExpansionTile(
      title: Text(context.loc.productFormAdvanced),
      childrenPadding: const EdgeInsets.symmetric(vertical: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        _field(TextFormField(
          controller: _wholesalePrice,
          enabled: canSetPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: canSetPrice
                ? context.loc.productFormWholesalePrice
                : context.loc.billingPriceLocked,
            prefixText: currency.isEmpty ? null : '$currency ',
          ),
          validator: (value) {
            if (!canSetPrice || value == null || value.trim().isEmpty) {
              return null;
            }
            final parsed = double.tryParse(
              value.trim().replaceAll(',', '.'),
            );
            if (parsed == null || parsed <= 0) {
              return context.loc.productFormPriceRequired;
            }
            return null;
          },
        )),
        _field(DropdownButtonFormField<String>(
          initialValue: _categoryId,
          decoration: InputDecoration(
            labelText: context.loc.productFormCategory,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.loc.productFormOptional),
            ),
            ...ready.categories.map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        )),
        _field(DropdownButtonFormField<String>(
          initialValue: _brandId,
          decoration: InputDecoration(
            labelText: context.loc.productFormBrand,
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.loc.productFormOptional),
            ),
            ...ready.brands.map(
              (brand) => DropdownMenuItem(
                value: brand.id,
                child: Text(brand.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _brandId = value),
        )),
        _field(TextFormField(
          controller: _sku,
          decoration: InputDecoration(
            labelText: context.loc.productFormSku,
            hintText: context.loc.productFormOptional,
          ),
        )),
        _field(TextFormField(
          controller: _barcode,
          decoration: InputDecoration(
            labelText: context.loc.productFormBarcode,
            hintText: context.loc.productFormOptional,
          ),
        )),
        _field(TextFormField(
          controller: _description,
          decoration: InputDecoration(
            labelText: context.loc.productFormDescription,
            hintText: context.loc.productFormOptional,
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
        )),
      ],
    );
  }

  Widget _field(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      );

  Future<void> _loadExisting(CatalogReady ready) async {
    try {
      final repository = ref.read(productRepositoryProvider);
      final product = await repository.getById(widget.productId!);
      double? price;
      double? wholesalePrice;
      final priceList = await repository.defaultPriceList();
      if (priceList != null) {
        final rows = await repository.prices(priceList.id);
        price = rows
            .where((row) => row.productId == product.id && row.priceType == 0)
            .map((row) => row.price)
            .firstOrNull;
        wholesalePrice = rows
            .where((row) => row.productId == product.id && row.priceType == 1)
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
        _description.text = product.description ?? '';
        _unitId = ready.units.any((u) => u.id == product.unitOfMeasureId)
            ? product.unitOfMeasureId
            : ready.units.firstOrNull?.id;
        _categoryId = ready.categories.any((c) => c.id == product.categoryId)
            ? product.categoryId
            : null;
        _brandId = ready.brands.any((b) => b.id == product.brandId)
            ? product.brandId
            : null;
        _productType = product.productType;
        // Kept silent so an update never wipes it; surfaced again by the TRA
        // add-on that will re-enable tax selection.
        _taxCategoryId = product.taxCategoryId;
        if (product.costPrice != null) {
          _costPrice.text = product.costPrice! % 1 == 0
              ? product.costPrice!.toStringAsFixed(0)
              : product.costPrice!.toStringAsFixed(2);
        }
        if (price != null) {
          _price.text = price % 1 == 0
              ? price.toStringAsFixed(0)
              : price.toStringAsFixed(2);
        }
        if (wholesalePrice != null) {
          _wholesalePrice.text = wholesalePrice % 1 == 0
              ? wholesalePrice.toStringAsFixed(0)
              : wholesalePrice.toStringAsFixed(2);
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
      description:
          Product.hasText(_description.text) ? _description.text.trim() : null,
      sku: Product.hasText(_sku.text) ? _sku.text.trim() : null,
      barcode: Product.hasText(_barcode.text) ? _barcode.text.trim() : null,
      categoryId: _categoryId,
      brandId: _brandId,
      taxCategoryId: _taxCategoryId,
      costPrice: double.tryParse(_costPrice.text.trim().replaceAll(',', '.')),
    );
    final sellingPrice = ref.read(fullBillingAccessProvider)
        ? double.tryParse(_price.text.trim().replaceAll(',', '.'))
        : null;
    final wholesalePriceText = _wholesalePrice.text.trim().replaceAll(',', '.');
    final wholesalePrice =
        ref.read(fullBillingAccessProvider) && wholesalePriceText.isNotEmpty
            ? double.tryParse(wholesalePriceText)
            : null;

    try {
      if (widget.isEdit) {
        await ref.read(productsControllerProvider.notifier).update(
              widget.productId!,
              draft,
              sellingPrice,
              wholesalePrice: wholesalePrice,
            );
        if (mounted) {
          context.pop();
        }
        return;
      }

      final created =
          await ref.read(productsControllerProvider.notifier).create(
                draft,
                sellingPrice,
                wholesalePrice: wholesalePrice,
              );
      if (!mounted) {
        return;
      }
      // Replace the form with the list; the caller offers opening stock.
      context.pop(created);
    } on ConflictException {
      setState(() {
        _saving = false;
        _error = context.loc.productFormDuplicate;
      });
    } on ValidationException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } on ForbiddenException {
      setState(() {
        _saving = false;
        _error = context.loc.productFormForbidden;
      });
    } on PaymentRequiredException {
      setState(() {
        _saving = false;
        _error = context.loc.billingPriceLockedMessage;
      });
      unawaited(
        ref.read(subscriptionEntitlementControllerProvider.notifier).refresh(),
      );
    } on NetworkException {
      setState(() {
        _saving = false;
        _error = context.loc.productFormNetwork;
      });
    } on AppException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }
}
