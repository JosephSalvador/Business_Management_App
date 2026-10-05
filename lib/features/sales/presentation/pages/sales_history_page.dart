import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../../../shared/format/money.dart';
import '../../application/sales_history_controller.dart';
import '../../domain/sale.dart';

/// One day's sales with Leo/Jana/custom-date navigation and receipt-number
/// search. Tapping a sale opens its details, where the receipt is one tap away.
class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  DateTime _day = DateTime.now();

  bool get _isToday => _sameDay(_day, DateTime.now());
  bool get _isYesterday => _sameDay(
        _day,
        DateTime.now().subtract(const Duration(days: 1)),
      );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(salesHistoryControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() => ref
      .read(salesHistoryControllerProvider.notifier)
      .load(day: _day, search: _search.text);

  void _selectDay(DateTime day) {
    setState(() => _day = day);
    _reload();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _selectDay(picked);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryControllerProvider);
    final loc = context.loc;
    final searching = state is SalesHistoryLoaded && state.searchActive;

    return Scaffold(
      appBar: AppBar(title: Text(loc.salesHistoryTitle)),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateBar(
                    isToday: _isToday,
                    isYesterday: _isYesterday,
                    customLabel: (_isToday || _isYesterday)
                        ? null
                        : DateFormat('d MMM yyyy').format(_day),
                    onToday: () => _selectDay(DateTime.now()),
                    onYesterday: () => _selectDay(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    onPick: _pickDate,
                    loc: loc,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _reload(),
                    decoration: InputDecoration(
                      hintText: loc.salesHistorySearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: loc.commonClear,
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
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
                ],
              ),
            ),
            Expanded(
              child: switch (state) {
                SalesHistoryLoading() =>
                  const Center(child: CircularProgressIndicator()),
                SalesHistoryFailure(:final message) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                SalesHistoryLoaded() when state.isEmpty => Center(
                    child: Text(
                      searching
                          ? loc.salesHistoryEmptySearch
                          : loc.salesHistoryEmptyDay,
                      style: TextStyle(
                          color: AppColors.resolveTextTertiary(context)),
                    ),
                  ),
                SalesHistoryLoaded() => RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      itemCount: state.sales.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _SaleTile(sale: state.sales[index], loc: loc),
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.isToday,
    required this.isYesterday,
    required this.customLabel,
    required this.onToday,
    required this.onYesterday,
    required this.onPick,
    required this.loc,
  });

  final bool isToday;
  final bool isYesterday;
  final String? customLabel;
  final VoidCallback onToday;
  final VoidCallback onYesterday;
  final VoidCallback onPick;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChoiceChip(
          label: Text(loc.salesHistoryToday),
          selected: isToday,
          onSelected: (_) => onToday(),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(loc.salesHistoryYesterday),
          selected: isYesterday,
          onSelected: (_) => onYesterday(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: loc.salesHistoryPickDate,
          onPressed: onPick,
        ),
        if (customLabel != null) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              customLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.loc});

  final SaleDto sale;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final time = sale.saleDate.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final detail = <String>[
      '${two(time.hour)}:${two(time.minute)}',
      if (sale.payments.isNotEmpty) sale.payments.first.label,
      if (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
        sale.customerName!,
    ];

    return ListTile(
      leading: sale.isVoided
          ? Icon(Icons.cancel_outlined,
              color: Theme.of(context).colorScheme.error)
          : const Icon(Icons.receipt_outlined),
      title: Text(
        sale.number.isEmpty ? loc.salesHistoryNoNumber : sale.number,
        style: TextStyle(
          decoration: sale.isVoided ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(detail.join(' · ')),
      trailing: Text(
        formatMoney(sale.totalAmount),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      onTap: () => context.push(Routes.saleDetail(sale.id)),
    );
  }
}
