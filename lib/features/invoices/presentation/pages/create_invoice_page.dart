import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../application/invoices_controller.dart';
import '../../domain/invoice.dart';

class CreateInvoicePage extends ConsumerStatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  ConsumerState<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends ConsumerState<CreateInvoicePage> {
  final _notesController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _lines = <_LineInputs>[_LineInputs()];
  String? _customerId;
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(customersControllerProvider.notifier).load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _dueDateController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (sum, line) => sum + line.lineTotal);

  bool get _canSave =>
      !_saving && _lines.any((line) => line.description.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final customersState = ref.watch(customersControllerProvider);
    final customerIds = customersState is CustomersLoaded
        ? {
            for (final customer in customersState.items)
              if (customer['id'] is String)
                customer['id'] as String:
                    ((customer['name'] as String?) ?? '').trim(),
          }
        : <String, String>{};

    return Scaffold(
      appBar: AppBar(title: Text(loc.invoiceNewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _customerId,
            isExpanded: true,
            decoration: InputDecoration(labelText: loc.invoiceCustomer),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(loc.invoiceWalkIn),
              ),
              for (final entry in customerIds.entries)
                DropdownMenuItem<String>(
                    value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _customerId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dueDateController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: loc.invoiceDueDate,
              hintText: 'YYYY-MM-DD',
            ),
            onTap: _pickDueDate,
          ),
          const SizedBox(height: 16),
          for (final line in _lines)
            _LineCard(
              inputs: line,
              canRemove: _lines.length > 1,
              onRemove: () {
                setState(() {
                  _lines.remove(line);
                  line.dispose();
                });
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _lines.add(_LineInputs())),
              icon: const Icon(Icons.add),
              label: Text(loc.invoiceAddLine),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${loc.invoiceTotal}: ${formatMoney(_subtotal)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(labelText: loc.invoiceNotes),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(loc.invoiceSave),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = picked;
      _dueDateController.text = _isoDate(picked);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final drafts = _lines
        .where((line) => line.description.text.trim().isNotEmpty)
        .map(
          (line) => InvoiceDraftLine(
            description: line.description.text,
            quantity: line.parsedQuantity,
            unitPrice: line.parsedUnitPrice,
            taxRatePercent: 0,
          ),
        )
        .toList(growable: false);
    final invoice = await ref.read(invoicesControllerProvider.notifier).create(
          lines: drafts,
          customerId: _customerId,
          dueDate: _dueDate,
          notes: _notesController.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (invoice == null) {
      final state = ref.read(invoicesControllerProvider);
      setState(() => _error = state is InvoicesFailure
          ? state.message
          : 'Ankara haikuweza kuhifadhiwa.');
      return;
    }
    context.go(Routes.invoiceDetail(invoice.id));
  }

  static String _isoDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _LineInputs {
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();

  double get parsedQuantity => double.tryParse(quantity.text.trim()) ?? 1;

  double get parsedUnitPrice => double.tryParse(unitPrice.text.trim()) ?? 0;

  double get lineTotal => parsedQuantity * parsedUnitPrice;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard(
      {required this.inputs, required this.canRemove, required this.onRemove});

  final _LineInputs inputs;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputs.description,
                    decoration:
                        InputDecoration(labelText: loc.invoiceLineDescription),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: loc.invoiceRemoveLine,
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputs.quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: loc.invoiceLineQuantity),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: inputs.unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        InputDecoration(labelText: loc.invoiceLineUnitPrice),
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
