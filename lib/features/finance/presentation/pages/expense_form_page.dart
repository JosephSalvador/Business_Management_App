import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/payment_labels.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/expense_providers.dart';
import '../../data/expense_repository.dart';

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
  final _paymentMethodController = TextEditingController(text: 'Pesa Taslimu');
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _expenseDate = DateTime.now();
  String _categoryId = '';
  ExpenseCategory? _createdCategory;
  bool _saving = false;
  bool _loading = false;
  bool _showMoreDetails = false;

  final List<String> _paymentMethods = [
    'Pesa Taslimu',
    'M-Pesa',
    'Benki',
    'Nyingine',
  ];

  static const List<String> _quickSuggestions = [
    'Kodi ya Pango',
    'Umeme / Luku',
    'Maji',
    'Usafiri / Nauli',
    'Chakula cha Wafanyakazi',
    'Mawasiliano / Vocha',
    'Ukarabati / Matengenezo',
  ];

  static const List<int> _quickAmounts = [
    5000,
    10000,
    20000,
    50000,
    100000,
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
        _paymentMethodController.text =
            expense['paymentMethod'] ?? 'Pesa Taslimu';
        _referenceController.text = expense['reference'] ?? '';
        _notesController.text = expense['notes'] ?? '';
        _categoryId = expense['categoryId'] as String? ?? '';
        final dateStr = expense['expenseDate'];
        if (dateStr != null) {
          _expenseDate = DateTime.parse(dateStr).toLocal();
        }
        if (_referenceController.text.isNotEmpty ||
            _notesController.text.isNotEmpty) {
          _showMoreDetails = true;
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

  void _addQuickAmount(int value) {
    final current = double.tryParse(_amountController.text) ?? 0.0;
    final updated = current + value;
    _amountController.text = updated % 1 == 0
        ? updated.toInt().toString()
        : updated.toStringAsFixed(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // ── Amount Card (Hero) ──────────────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                      ),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.expenseAmount,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.resolveTextSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              decoration: InputDecoration(
                                prefixText: 'TSh  ',
                                prefixStyle:
                                    theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppColors.resolveTextSecondary(context),
                                ),
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return loc.expenseAmountRequired;
                                }
                                final amount = double.tryParse(v.trim());
                                if (amount == null || amount <= 0) {
                                  return loc.expenseAmountInvalid;
                                }
                                return null;
                              },
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _quickAmounts.map((val) {
                                return ActionChip(
                                  label:
                                      Text('+${formatMoney(val.toDouble())}'),
                                  labelStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: () => _addQuickAmount(val),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Description Card ───────────────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                      ),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.expenseDescription,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.resolveTextSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText:
                                    'Mfano: Kodi ya mwezi, Luku ya duka...',
                                filled: true,
                                fillColor: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? loc.expenseDescriptionRequired
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chaguzi za Haraka:',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.resolveTextTertiary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _quickSuggestions.map((suggestion) {
                                return ActionChip(
                                  label: Text(suggestion),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: () {
                                    setState(() {
                                      _descriptionController.text = suggestion;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Category Card ──────────────────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                      ),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.expenseCategory,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color:
                                        AppColors.resolveTextSecondary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () async {
                                    final created = await _addCategory(loc);
                                    if (created != null) {
                                      setState(() {
                                        _createdCategory = created;
                                        _categoryId = created.id;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(loc.expenseCategoryAdd),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            categoriesAsync.when(
                              data: (cats) {
                                final allCats = [
                                  if (_createdCategory != null &&
                                      !cats.any(
                                          (c) => c.id == _createdCategory!.id))
                                    _createdCategory!,
                                  ...cats,
                                ];

                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: Text(loc.expenseCategoryNone),
                                      selected: _categoryId.isEmpty,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => _categoryId = '');
                                        }
                                      },
                                    ),
                                    ...allCats.map((cat) {
                                      final isSelected = _categoryId == cat.id;
                                      return ChoiceChip(
                                        label: Text(cat.name),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() => _categoryId =
                                              selected ? cat.id : '');
                                        },
                                      );
                                    }),
                                  ],
                                );
                              },
                              loading: () => const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Payment Method & Date Card ─────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                      ),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.expensePaymentMethod,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.resolveTextSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _paymentMethods.map((method) {
                                final isSelected =
                                    _paymentMethodController.text == method;
                                return ChoiceChip(
                                  label: Text(
                                      storedPaymentMethodLabel(loc, method)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _paymentMethodController
                                          .text = method);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const Divider(height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calendar_month,
                                    color: AppColors.primary, size: 20),
                              ),
                              title: Text(
                                loc.expenseDate,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy').format(_expenseDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppColors.resolveTextSecondary(context),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _pickDate,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── More Details (Collapsible) ─────────────────
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                      ),
                      color: theme.colorScheme.surface,
                      child: ExpansionTile(
                        initiallyExpanded: _showMoreDetails,
                        shape: const Border(),
                        leading: const Icon(Icons.more_horiz,
                            color: AppColors.primary),
                        title: const Text(
                          'Maelezo Zaidi (Hiari)',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Namba ya risiti, kumbukumbu, au dokezo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.resolveTextTertiary(context),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _referenceController,
                                  decoration: InputDecoration(
                                    labelText: loc.expenseReference,
                                    hintText: 'Namba ya risiti au rejea',
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: InputDecoration(
                                    labelText: loc.expenseNotes,
                                    hintText:
                                        'Maelezo ya ziada kuhusu gharama hii...',
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    isDense: true,
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Save Button ────────────────────────────────
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        isEdit ? loc.commonSave : loc.expenseAdd,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 32),
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
        'amount': double.parse(_amountController.text.trim()),
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
