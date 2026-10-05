import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

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
  final List<Map<String, dynamic>> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final warehousesAsync = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.purchasesAdd),
      ),
      body: WaveBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              suppliersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(context.loc.commonWithError('$e')),
                data: (pagedSuppliers) => DropdownButtonFormField<String>(
                  initialValue: _selectedSupplierId,
                  decoration:
                      InputDecoration(labelText: context.loc.purchasesSupplier),
                  items:
                      pagedSuppliers.items.map<DropdownMenuItem<String>>((s) {
                    return DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSupplierId = v),
                  validator: (v) =>
                      v == null ? context.loc.purchasesSupplierRequired : null,
                ),
              ),
              const SizedBox(height: 16),
              warehousesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(context.loc.commonWithError('$e')),
                data: (warehouses) => DropdownButtonFormField<String>(
                  initialValue: _selectedWarehouseId,
                  decoration:
                      InputDecoration(labelText: context.loc.purchasesOffice),
                  items: warehouses.map<DropdownMenuItem<String>>((w) {
                    return DropdownMenuItem(
                      value: w['id'] as String,
                      child: Text(w['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                  validator: (v) =>
                      v == null ? context.loc.purchasesOfficeRequired : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration:
                    InputDecoration(labelText: context.loc.purchasesReference),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration:
                    InputDecoration(labelText: context.loc.purchasesNotes),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    context.loc.navProducts,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: Text(context.loc.commonAdd),
                  ),
                ],
              ),
              if (_lines.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        context.loc.purchasesEmptyLines,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ),
              ..._lines.asMap().entries.map((entry) {
                final index = entry.key;
                final line = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line['productName'] ?? context.loc.navProducts,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${line['quantity']} x TSh ${line['unitPrice']}',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              setState(() => _lines.removeAt(index)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(context.loc.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addLine() {
    showDialog(
      context: context,
      builder: (context) => _AddLineDialog(
        onAdd: (line) {
          setState(() => _lines.add(line));
        },
      ),
    );
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
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'lines': _lines,
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
}

class _AddLineDialog extends StatefulWidget {
  const _AddLineDialog({required this.onAdd});

  final ValueChanged<Map<String, dynamic>> onAdd;

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return AlertDialog(
      title: Text(loc.purchasesAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            decoration: InputDecoration(labelText: loc.purchasesLineQuantity),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(labelText: loc.purchasesLineUnitPrice),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final qty = int.tryParse(_quantityController.text) ?? 1;
            final price = double.tryParse(_priceController.text) ?? 0;
            widget.onAdd({
              'productId': '00000000-0000-0000-0000-000000000000',
              'productName': loc.navProducts,
              'quantity': qty,
              'unitPrice': price,
            });
            Navigator.pop(context);
          },
          child: Text(loc.commonAdd),
        ),
      ],
    );
  }
}
