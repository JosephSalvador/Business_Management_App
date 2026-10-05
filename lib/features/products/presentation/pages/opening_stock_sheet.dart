import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../application/catalog_controller.dart';
import '../../data/product_repository.dart';
import '../../domain/product.dart';

/// Bottom sheet that records opening stock for a freshly created product.
/// The warehouse is chosen automatically (the default "Main Store") — normal
/// users never manage warehouses. Returns the recorded quantity on success.
class OpeningStockSheet extends ConsumerStatefulWidget {
  const OpeningStockSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<OpeningStockSheet> createState() => _OpeningStockSheetState();
}

class _OpeningStockSheetState extends ConsumerState<OpeningStockSheet> {
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = context.loc;
    final parsed = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0) {
      setState(() => _error = loc.addStockInvalidQuantity);
      return;
    }
    final catalog = ref.read(catalogControllerProvider);
    if (catalog is! CatalogReady || catalog.defaultWarehouse == null) {
      setState(() => _error = loc.addStockWarehouseUnavailable);
      return;
    }
    final unitCost = double.tryParse(
      _unitCostController.text.trim().replaceAll(',', '.'),
    );
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(stockControllerProvider.notifier).recordOpening(
            OpeningStockEntry(
              warehouseId: catalog.defaultWarehouse!.id,
              productId: widget.product.id,
              quantity: parsed,
              unitOfMeasureId: widget.product.unitOfMeasureId,
              reason: loc.openingStockReason,
              unitCost: unitCost,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(parsed);
      }
    } on ConflictException {
      setState(() {
        _saving = false;
        _error = loc.openingStockDuplicate;
      });
    } on AppException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.openingStockTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(loc.addStockProduct(widget.product.name)),
          const SizedBox(height: 20),
          TextField(
            controller: _quantityController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: loc.addStockQuantity,
              errorText: _error,
            ),
            onSubmitted: (_) {
              if (!_saving) _save();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unitCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: loc.stockUnitCostOptional,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(loc.addStockWarehouse),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(loc.addStockSave),
          ),
        ],
      ),
    );
  }
}
