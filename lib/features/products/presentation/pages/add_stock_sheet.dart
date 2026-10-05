import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../l10n/loc.dart';
import '../../application/catalog_controller.dart';
import '../../data/product_repository.dart';

/// Bottom sheet that tops up stock for an existing product through the stock
/// adjustment endpoint (positive delta). The warehouse is chosen automatically
/// (the default "Main Store") — users never manage warehouses. Returns the
/// recorded quantity on success.
///
/// A client GUID is drawn for the first submit and kept across retries, so a
/// dropped response never double-counts stock when the user taps Save again
/// (the backend dedupes on the Idempotency-Key header).
class AddStockSheet extends ConsumerStatefulWidget {
  const AddStockSheet({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  ConsumerState<AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<AddStockSheet> {
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  String? _selectedReasonType;
  String? _error;
  bool _saving = false;
  String? _commitKey;

  static const _reasonTypes = <MapEntry<String, String>>[
    MapEntry('Purchase', 'Purchase'),
    MapEntry('Return', 'Return'),
    MapEntry('Adjustment', 'Adjustment'),
    MapEntry('Transfer', 'Transfer'),
    MapEntry('Production', 'Production'),
  ];

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
    if (_selectedReasonType == null) {
      setState(() => _error = loc.stockReasonRequired);
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
      _commitKey ??= const Uuid().v4();
      await ref.read(stockControllerProvider.notifier).adjustStock(
            AdjustStockEntry(
              warehouseId: catalog.defaultWarehouse!.id,
              productId: widget.productId,
              quantityDelta: parsed,
              reason: _selectedReasonType,
              unitCost: unitCost,
              reasonType: _selectedReasonType,
              idempotencyKey: _commitKey,
            ),
          );
      _commitKey = null;
      if (mounted) {
        Navigator.of(context).pop(parsed);
      }
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
            loc.addStockTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(loc.addStockProduct(widget.productName)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedReasonType,
            decoration: InputDecoration(
              labelText: loc.stockReasonLabel,
            ),
            items: _reasonTypes
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.key),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedReasonType = v),
          ),
          const SizedBox(height: 12),
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
