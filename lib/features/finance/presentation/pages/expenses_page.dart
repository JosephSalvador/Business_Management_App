import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../data/expense_providers.dart';
import '../../data/expense_repository.dart';

enum _ExpenseRange { today, yesterday, month, all, custom }

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  _ExpenseRange _range = _ExpenseRange.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loadingMore = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) {
    final controller = ref.read(expensesControllerProvider.notifier);
    switch (_range) {
      case _ExpenseRange.all:
        return controller.load(search: _search.text, silent: silent);
      case _ExpenseRange.today:
      case _ExpenseRange.yesterday:
      case _ExpenseRange.month:
      case _ExpenseRange.custom:
        return controller.load(
          search: _search.text,
          fromDate: _from(),
          toDate: _to(),
          silent: silent,
        );
    }
  }

  DateTime? _from() {
    final now = DateTime.now();
    switch (_range) {
      case _ExpenseRange.today:
        return now;
      case _ExpenseRange.yesterday:
        return now.subtract(const Duration(days: 1));
      case _ExpenseRange.month:
        return DateTime(now.year, now.month, 1);
      case _ExpenseRange.custom:
        return _customStart;
      case _ExpenseRange.all:
        return null;
    }
  }

  DateTime? _to() {
    final now = DateTime.now();
    switch (_range) {
      case _ExpenseRange.today:
        return now;
      case _ExpenseRange.yesterday:
        return now.subtract(const Duration(days: 1));
      case _ExpenseRange.month:
        return DateTime(now.year, now.month + 1, 0);
      case _ExpenseRange.custom:
        return _customEnd;
      case _ExpenseRange.all:
        return null;
    }
  }

  void _select(_ExpenseRange range) {
    setState(() => _range = range);
    _reload();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now, end: now),
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _range = _ExpenseRange.custom;
      });
      _reload();
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _filter = value.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _reload(silent: true);
    });
  }

  Future<void> _onLoadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    await ref.read(expensesControllerProvider.notifier).loadMore();
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesControllerProvider);
    final loc = context.loc;
    final searching = _filter.isNotEmpty ||
        (state is ExpensesLoaded && state.search.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.expenseTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/expenses/new'),
          ),
        ],
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRangeChips(loc),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _reload(silent: true),
                    decoration: InputDecoration(
                      hintText: loc.expenseSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: loc.commonClear,
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
                                setState(() => _filter = '');
                                _reload();
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (state is ExpensesLoaded && state.summary != null)
                    _SummaryCard(summary: state.summary!, loc: loc),
                ],
              ),
            ),
            Expanded(child: _buildBody(state, loc, searching)),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeChips(AppLocalizations loc) {
    final shortFormat = DateFormat('d MMM');
    final customLabel = _range == _ExpenseRange.custom &&
            _customStart != null &&
            _customEnd != null
        ? '${shortFormat.format(_customStart!)} – ${shortFormat.format(_customEnd!)}'
        : loc.expensePickRange;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(loc.expenseToday),
            selected: _range == _ExpenseRange.today,
            onSelected: (_) => _select(_ExpenseRange.today),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(loc.expenseYesterday),
            selected: _range == _ExpenseRange.yesterday,
            onSelected: (_) => _select(_ExpenseRange.yesterday),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(loc.expenseThisMonth),
            selected: _range == _ExpenseRange.month,
            onSelected: (_) => _select(_ExpenseRange.month),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(loc.expenseAllTime),
            selected: _range == _ExpenseRange.all,
            onSelected: (_) => _select(_ExpenseRange.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(customLabel),
            selected: _range == _ExpenseRange.custom,
            onSelected: (_) => _pickRange(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ExpensesState state, AppLocalizations loc, bool searching) {
    return switch (state) {
      ExpensesLoading() => const Center(child: CircularProgressIndicator()),
      ExpensesFailure(:final message) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _reload,
                child: Text(loc.commonRetry),
              ),
            ],
          ),
        ),
      ExpensesLoaded(:final items, :final hasMore) => () {
          final filtered = _filter.isEmpty
              ? items
              : items.where((e) {
                  final cat = (e['categoryName'] ?? e['category'] ?? '')
                      .toString()
                      .toLowerCase();
                  final desc =
                      (e['description'] ?? '').toString().toLowerCase();
                  final amt = (e['amount'] ?? '').toString();
                  return cat.contains(_filter) ||
                      desc.contains(_filter) ||
                      amt.contains(_filter);
                }).toList();

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 240,
                    child: _filter.isNotEmpty || searching
                        ? Center(
                            child: Text(
                              _filter.isNotEmpty
                                  ? 'Hakuna matumizi yaliyopatikana kwa "$_filter"'
                                  : loc.expenseEmptySearch,
                              style: TextStyle(
                                  color:
                                      AppColors.resolveTextTertiary(context)),
                            ),
                          )
                        : EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: loc.expenseEmpty,
                            message: loc.expenseEmptyMessage,
                            actionLabel: loc.expenseAdd,
                            onAction: () => context.push('/expenses/new'),
                          ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length + (hasMore && _filter.isEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  if (hasMore && _filter.isEmpty) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _onLoadMore());
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return _buildExpenseTile(context, filtered[index], loc);
              },
            ),
          );
        }(),
    };
  }

  Widget _buildExpenseTile(BuildContext context, Map<String, dynamic> expense,
      AppLocalizations loc) {
    final theme = Theme.of(context);
    final tertiary = AppColors.resolveTextTertiary(context);
    final expenseColor = theme.colorScheme.error;
    final pendingColor = theme.colorScheme.tertiary;
    final description = expense['description'] ?? '';
    final amount = (expense['amount'] ?? 0).toDouble();
    final dateStr = expense['expenseDate'] ?? expense['createdAt'] ?? '';
    final date =
        dateStr.isNotEmpty ? DateTime.tryParse(dateStr)?.toLocal() : null;
    final category = expense['categoryName'] as String?;
    final isPending = expense['pendingLocally'] == true;

    final detail = <String>[
      if (isPending) 'Nje ya mtandao (Outbox)',
      if (date != null) DateFormat('dd/MM/yyyy').format(date),
      if (category != null && category.trim().isNotEmpty) category,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPending
                ? pendingColor.withValues(alpha: 0.15)
                : expenseColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPending ? Icons.cloud_off : Icons.receipt_long,
            color: isPending ? pendingColor : expenseColor,
            size: 20,
          ),
        ),
        title: Text(description,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface)),
        subtitle: detail.isEmpty
            ? null
            : Text(
                detail.join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: isPending ? pendingColor : tertiary,
                  fontWeight: isPending ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
        trailing: Text(
          formatMoney(amount),
          style: TextStyle(fontWeight: FontWeight.w600, color: expenseColor),
        ),
        onTap: () => context.push('/expenses/${expense['id']}/edit'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.loc});

  final ExpenseSummary summary;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final categories = summary.byCategory.take(3).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.expenseSummaryTitle,
            style: TextStyle(
                fontSize: 13, color: AppColors.resolveTextTertiary(context)),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(summary.total),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in categories)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${line.categoryName ?? loc.expenseCategoryNone} — ${formatMoney(line.total)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              loc.expenseSummaryEmpty,
              style: TextStyle(
                  fontSize: 13, color: AppColors.resolveTextTertiary(context)),
            ),
          ],
        ],
      ),
    );
  }
}
