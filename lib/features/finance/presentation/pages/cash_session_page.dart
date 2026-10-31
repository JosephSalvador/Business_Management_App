import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../l10n/loc.dart';
import '../../data/money_account_providers.dart';
import '../../../sales/data/sales_providers.dart';

class CashSessionPage extends ConsumerStatefulWidget {
  const CashSessionPage({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<CashSessionPage> createState() => _CashSessionPageState();
}

class _CashSessionPageState extends ConsumerState<CashSessionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref
        .read(cashSessionControllerProvider.notifier)
        .load(widget.accountId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.cashTitle),
      ),
      body: WaveBackground(
        child: switch (state) {
          CashSessionLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          CashSessionFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(cashSessionControllerProvider.notifier)
                        .load(widget.accountId),
                    child: Text(context.loc.commonRetry),
                  ),
                ],
              ),
            ),
          CashSessionLoaded(:final session, :final hasOpenSession) =>
            hasOpenSession
                ? _buildOpenSession(context, ref, session!)
                : _buildClosedOrNone(context, ref, session),
        },
      ),
    );
  }

  Widget _buildClosedOrNone(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? session) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (session != null) ...[
            _buildSessionSummary(session),
            const SizedBox(height: 24),
          ],
          Card(
            elevation: isDark ? 0 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant
                    .withValues(alpha: isDark ? 0.3 : 0.7),
              ),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.cashOpenNew,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.loc.cashOpenInstructions,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OpenSessionForm(accountId: widget.accountId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenSession(
      BuildContext context, WidgetRef ref, Map<String, dynamic> session) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final openingCash = (session['openingCash'] ?? 0).toDouble();
    final openedAtStr = session['openedAt'] ?? '';
    final openedAt =
        openedAtStr.isNotEmpty ? DateTime.tryParse(openedAtStr) : null;

    return FutureBuilder<ShiftSummary>(
      future: ref
          .read(offlineShiftRegisterServiceProvider)
          .computeShiftSummary(openingCash: openingCash),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final expectedCash = summary?.expectedCash ?? openingCash;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.4 : 0.3),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lock_open,
                        color: Color(0xFF16A34A),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.loc.cashOpenBadge,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: isDark ? 0.3 : 0.7),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Kiasi Kilichopo Droo (Kinachotarajiwa)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.resolveTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatMoney(expectedCash),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summaryRow(context.loc.cashOpeningAmount,
                        formatMoney(openingCash)),
                    if (summary != null) ...[
                      _summaryRow('Mauzo ya Pesa Taslimu (+)',
                          formatMoney(summary.cashSales),
                          valueColor: const Color(0xFF16A34A)),
                      _summaryRow('Marejesho ya Madeni (+)',
                          formatMoney(summary.debtCashCollected),
                          valueColor: const Color(0xFF16A34A)),
                      _summaryRow('Matumizi ya Pesa Taslimu (-)',
                          formatMoney(summary.cashExpenses),
                          valueColor: const Color(0xFFDC2626)),
                    ],
                    if (openedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.loc.cashOpenedAt(DateFormat('dd/MM/yyyy HH:mm')
                            .format(openedAt.toLocal())),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.resolveTextSecondary(context)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _showCloseDialog(
                    context,
                    ref,
                    session,
                    expectedCash: expectedCash,
                  ),
                  icon: const Icon(Icons.lock, size: 18),
                  label: Text(context.loc.cashCloseSession),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionSummary(Map<String, dynamic> session) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final openingCash = (session['openingCash'] ?? 0).toDouble();
    final closingCash = (session['closingCash'] as num?)?.toDouble();
    final expectedCash = (session['expectedCash'] as num?)?.toDouble();
    final variance = (session['variance'] as num?)?.toDouble();
    final closedAtStr = session['closedAt'] as String?;
    final closedAt =
        closedAtStr != null ? DateTime.tryParse(closedAtStr) : null;

    return Card(
      elevation: isDark ? 0 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant
              .withValues(alpha: isDark ? 0.3 : 0.7),
        ),
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
                  context.loc.cashClosedHeader,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.loc.cashClosedBadge,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const Divider(),
            _summaryRow(
                context.loc.cashOpeningAmount, formatMoney(openingCash)),
            if (closingCash != null)
              _summaryRow(
                  context.loc.cashClosingAmount, formatMoney(closingCash)),
            if (expectedCash != null)
              _summaryRow(context.loc.cashExpected, formatMoney(expectedCash)),
            if (variance != null) ...[
              const Divider(),
              _summaryRow(
                context.loc.cashDifference,
                formatMoney(variance),
                valueColor: variance == 0
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ],
            if (closedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                context.loc.cashClosedAt(
                    DateFormat('dd/MM/yyyy HH:mm').format(closedAt.toLocal())),
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.resolveTextSecondary(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.resolveTextSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session, {
    double? expectedCash,
  }) {
    final closingController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.loc.cashCloseSession),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.loc.cashCloseDialogHint,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: closingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.loc.cashClosingInput,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.loc.cashAmountRequired;
                    }
                    final amount = double.tryParse(v.trim());
                    if (amount == null || amount < 0) {
                      return context.loc.cashAmountInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: context.loc.cashNotesOptional,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.loc.commonCancel),
            ),
            ElevatedButton(
              onPressed: saving
              ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);

                      try {
                        final result = await ref
                            .read(cashSessionControllerProvider.notifier)
                            .closeSession(
                              session['id'] as String,
                              double.parse(closingController.text.trim()),
                              notesController.text.trim(),
                              widget.accountId,
                              expectedCash: expectedCash,
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          final variance =
                              (result['variance'] as num?)?.toDouble() ?? 0;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                variance == 0
                                    ? context.loc.cashClosedBalanced
                                    : context.loc.cashClosedVariance(
                                        formatMoney(variance)),
                              ),
                              backgroundColor: variance == 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text(
                                    context.loc.commonWithError(e.toString()))),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.loc.cashCloseButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenSessionForm extends ConsumerStatefulWidget {
  const _OpenSessionForm({required this.accountId});

  final String accountId;

  @override
  ConsumerState<_OpenSessionForm> createState() => _OpenSessionFormState();
}

class _OpenSessionFormState extends ConsumerState<_OpenSessionForm> {
  final _formKey = GlobalKey<FormState>();
  final _openingCashController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _openingCashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _openingCashController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.loc.cashOpeningInput,
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return context.loc.cashAmountRequired;
              }
              final amount = double.tryParse(v.trim());
              if (amount == null || amount < 0) {
                return context.loc.cashAmountInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _openSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.loc.cashOpenNew),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSession() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await ref.read(cashSessionControllerProvider.notifier).openSession(
            widget.accountId,
            double.parse(_openingCashController.text.trim()),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.cashOpenedSuccess),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.commonWithError(e.toString()))),
        );
      }
    }
  }
}
