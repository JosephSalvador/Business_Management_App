import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/network/app_exception.dart';
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
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Weka idadi sahihi (zaidi ya sifuri).');
      return;
    }
    final catalog = ref.read(catalogControllerProvider);
    if (catalog is! CatalogReady || catalog.defaultWarehouse == null) {
      setState(() => _error = 'Mahali pa kuhifadhi hakipatikani. Jaribu tena.');
      return;
    }
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
              reason: 'Stock ya mwanzo',
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(parsed);
      }
    } on ConflictException {
      setState(() {
        _saving = false;
        _error = 'Stock ya mwanzo imesharekodiwa kwa bidhaa hii.';
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
            'Stock ya mwanzo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('Bidhaa: ${widget.product.name}'),
          const SizedBox(height: 20),
          TextField(
            controller: _quantityController,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Kiasi',
              errorText: _error,
            ),
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Ghala: Main Store'),
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
                : const Text('Hifadhi'),
          ),
        ],
      ),
    );
  }
}
