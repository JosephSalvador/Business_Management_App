import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/payment_labels.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/expense_providers.dart';
import '../../data/expense_repository.dart';

const String _addCategoryValue = '__add_category__';

class ExpenseFormPage extends ConsumerStatefulWidget {
  const ExpenseFormPage({super.key, this.expenseId});

  final String? expenseId;

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  String _categoryId = '';
  ExpenseCategory? _createdCategory;
  bool _saving = false;
  bool _loading = false;

  final List<String> _paymentMethods = [
    'Pesa Taslimu',
    'M-Pesa',
    'Benki',
    'Nyingine',
  ];

  bool get isEdit => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _loadExpense();
    }
  }

  Future<void> _loadExpense() async {
    setState(() => _loading = true);
    try {
      final expense = await ref
          .read(expensesControllerProvider.notifier)
          .getById(widget.expenseId!);
      if (mounted) {
        _descriptionController.text = expense['description'] ?? '';
        _amountController.text = (expense['amount'] ?? 0).toString();
        _paymentMethodController.text = expense['paymentMethod'] ?? '';
        _referenceController.text = expense['reference'] ?? '';
        _notesController.text = expense['notes'] ?? '';
        _categoryId = expense['categoryId'] as String? ?? '';
        final dateStr = expense['expenseDate'];
        if (dateStr != null) {
          _expenseDate = DateTime.parse(dateStr);
        }
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final categories = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? loc.expenseEditTitle : loc.expenseAddTitle),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: loc.commonDelete,
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: WaveBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      decoration:
                          InputDecoration(labelText: loc.expenseDescription),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? loc.expenseDescriptionRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                          labelText: loc.expenseAmount, prefixText: 'TSh '),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return loc.expenseAmountRequired;
                        }
                        final amount = double.tryParse(v);
                        if (amount == null || amount <= 0) {
                          return loc.expenseAmountInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(loc.expenseDate),
                      subtitle: Text(
                        '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 16),
                    categories.when(
                      data: (cats) {
                        final items = <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: '',
                            child: Text(loc.expenseCategoryNone),
                          ),
                          ...cats.map<DropdownMenuItem<String>>(
                            (c) => DropdownMenuItem(
                                value: c.id, child: Text(c.name)),
                          ),
                          if (_createdCategory != null &&
                              !cats.any((c) => c.id == _createdCategory!.id))
                            DropdownMenuItem(
                              value: _createdCategory!.id,
                              child: Text(_createdCategory!.name),
                            ),
                          DropdownMenuItem(
                            value: _addCategoryValue,
                            child: Text(loc.expenseCategoryAdd),
                          ),
                        ].where((it) => it.value != null).toList();
                        return DropdownButtonFormField<String>(
                          key: ValueKey('category-$_categoryId-${cats.length}'),
                          initialValue:
                              items.any((it) => it.value == _categoryId)
                                  ? _categoryId
                                  : '',
                          decoration:
                              InputDecoration(labelText: loc.expenseCategory),
                          items: items,
                          onChanged: (v) async {
                            if (v == _addCategoryValue) {
                              final created = await _addCategory(loc);
                              if (created != null) {
                                setState(() {
                                  _createdCategory = created;
                                  _categoryId = created.id;
                                });
                              }
                            } else {
                              setState(() => _categoryId = v ?? '');
                            }
                          },
                        );
                      },
                      loading: () => const SizedBox(
                        height: 56,
                        child: Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (_, __) => OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(loc.commonRetry),
                        onPressed: () =>
                            ref.invalidate(expenseCategoriesProvider),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethods
                              .contains(_paymentMethodController.text)
                          ? _paymentMethodController.text
                          : null,
                      decoration:
                          InputDecoration(labelText: loc.expensePaymentMethod),
                      items: _paymentMethods.map<DropdownMenuItem<String>>((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(storedPaymentMethodLabel(loc, m)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(
                          () => _paymentMethodController.text = v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceController,
                      decoration:
                          InputDecoration(labelText: loc.expenseReference),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(labelText: loc.expenseNotes),
                      maxLines: 3,
                    ),
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
                          : Text(isEdit ? loc.commonSave : loc.expenseAdd),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<ExpenseCategory?> _addCategory(AppLocalizations loc) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _NewCategoryDialog(loc: loc),
    );

    if (result == null) return null;
    try {
      final created =
          await ref.read(expenseRepositoryProvider).createCategory(result);
      ref.invalidate(expenseCategoriesProvider);
      return created;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
      return null;
    }
  }

  Future<void> _confirmDelete() async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.expenseDeleteConfirmTitle),
        content: Text(loc.expenseDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(expensesControllerProvider.notifier)
          .delete(widget.expenseId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final body = {
        'description': _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text),
        'expenseDate': _expenseDate.toUtc().toIso8601String(),
        if (_categoryId.isNotEmpty) 'categoryId': _categoryId,
        if (_paymentMethodController.text.isNotEmpty)
          'paymentMethod': _paymentMethodController.text,
        if (_referenceController.text.isNotEmpty)
          'reference': _referenceController.text.trim(),
        if (_notesController.text.isNotEmpty)
          'notes': _notesController.text.trim(),
      };

      if (isEdit) {
        await ref
            .read(expensesControllerProvider.notifier)
            .update(widget.expenseId!, body);
      } else {
        await ref.read(expensesControllerProvider.notifier).create(body);
      }

      if (mounted) {
        final loc = context.loc;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.expenseSaved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError('$e'))),
        );
      }
    }
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.loc});

  final AppLocalizations loc;

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.loc.expenseNewCategoryTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.loc.expenseCategoryName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.loc.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, name);
          },
          child: Text(widget.loc.commonSave),
        ),
      ],
    );
  }
}
