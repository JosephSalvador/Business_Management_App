import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/invoices_controller.dart';
import '../../domain/invoice.dart';
import '../widgets/invoice_branding_sheet.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    ref.read(invoicesControllerProvider.notifier).load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _filter = value.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(invoicesControllerProvider.notifier)
          .load(search: value.trim(), silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoicesControllerProvider);
    final loc = context.loc;
    final isSw = Localizations.localeOf(context).languageCode == 'sw';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.invoicesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.design_services_outlined),
            tooltip: isSw ? 'Violezo vya Ankara' : 'Document Templates',
            onPressed: () => context.push(Routes.documentTemplates),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip:
                isSw ? 'Nembo & Maelezo ya Benki' : 'Invoice Logo & Bank Info',
            onPressed: () => showInvoiceBrandingSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: loc.invoicesAdd,
            onPressed: () => context.push(Routes.invoiceNew),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.invoiceNew),
        icon: const Icon(Icons.add),
        label: Text(loc.invoicesAdd),
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSearchBar(
                controller: _searchController,
                hintText: loc.invoicesSearch,
                onChanged: _onSearchChanged,
              ),
            ),
            _StatusFilters(state: state),
            Expanded(child: _buildBody(state, isSw)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(InvoicesState state, bool isSwahili) {
    final loc = context.loc;
    return switch (state) {
      InvoicesLoading() => const Center(child: CircularProgressIndicator()),
      InvoicesFailure(:final message) => Center(
          child: Text(
            message,
            style: TextStyle(color: AppColors.resolveTextSecondary(context)),
          ),
        ),
      InvoicesLoaded(:final items) => () {
          final filtered = _filter.isEmpty
              ? items
              : items.where((inv) {
                  final num = inv.number.toLowerCase();
                  final name = inv.customerName.toLowerCase();
                  final refNo = (inv.referenceNumber ?? '').toLowerCase();
                  final amount = inv.totalAmount.toString();
                  return num.contains(_filter) ||
                      name.contains(_filter) ||
                      refNo.contains(_filter) ||
                      amount.contains(_filter);
                }).toList();

          if (filtered.isEmpty) {
            if (_filter.isNotEmpty) {
              return Center(
                child: Text(
                  isSwahili
                      ? 'Hakuna ankara iliyopatikana kwa "$_filter"'
                      : 'No invoices found matching "$_filter"',
                  style:
                      TextStyle(color: AppColors.resolveTextSecondary(context)),
                ),
              );
            }
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: loc.invoicesEmpty,
              message: loc.invoicesEmptyMessage,
              actionLabel: loc.invoicesAdd,
              onAction: () => context.push(Routes.invoiceNew),
            );
          }

          final activeItems = filtered
              .where((i) => i.status != InvoiceStatus.voided)
              .toList(growable: false);
          final totalBilled =
              activeItems.fold<double>(0, (s, i) => s + i.totalAmount);
          final totalOutstanding =
              activeItems.fold<double>(0, (s, i) => s + i.balanceDue);

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(invoicesControllerProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _InvoicesSummaryStrip(
                    totalBilled: totalBilled,
                    totalOutstanding: totalOutstanding,
                    isSwahili: isSwahili,
                  );
                }
                return _InvoiceTile(
                  invoice: filtered[index - 1],
                  isSwahili: isSwahili,
                );
              },
            ),
          );
        }(),
    };
  }
}

class _InvoicesSummaryStrip extends StatelessWidget {
  const _InvoicesSummaryStrip({
    required this.totalBilled,
    required this.totalOutstanding,
    required this.isSwahili,
  });

  final double totalBilled;
  final double totalOutstanding;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    final collected =
        (totalBilled - totalOutstanding).clamp(0.0, double.infinity);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              isSwahili ? 'Jumla ya Ankara' : 'Total Billed',
              formatMoney(totalBilled),
              Colors.white,
            ),
          ),
          Container(width: 1, height: 28, color: const Color(0xFF334155)),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              isSwahili ? 'Kilicholipwa' : 'Collected',
              formatMoney(collected),
              const Color(0xFF4ADE80),
            ),
          ),
          Container(width: 1, height: 28, color: const Color(0xFF334155)),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              isSwahili ? 'Salio (Deni)' : 'Outstanding',
              formatMoney(totalOutstanding),
              const Color(0xFFFBBF24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _StatusFilters extends ConsumerWidget {
  const _StatusFilters({required this.state});

  final InvoicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = context.loc;
    final selected = state is InvoicesLoaded
        ? (state as InvoicesLoaded).status
        : state is InvoicesLoading
            ? (state as InvoicesLoading).status
            : null;
    final filters = <(InvoiceStatus?, String)>[
      (null, loc.invoicesFilterAll),
      (InvoiceStatus.unpaid, loc.invoiceStatusUnpaid),
      (InvoiceStatus.partiallyPaid, loc.invoiceStatusPartial),
      (InvoiceStatus.paid, loc.invoiceStatusPaid),
      (InvoiceStatus.voided, loc.invoiceStatusVoid),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (status, label) = filters[index];
          return FilterChip(
            label: Text(label),
            selected: selected == status,
            onSelected: (_) {
              final controller = ref.read(invoicesControllerProvider.notifier);
              if (status == null) {
                controller.load(clearStatus: true);
              } else {
                controller.toggleStatus(status);
              }
            },
          );
        },
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.isSwahili,
  });

  final CustomerInvoiceSummary invoice;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final overdue = invoice.isOverdue;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                invoice.documentTitle.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      invoice.number,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: invoice.isSynced
                        ? (isSwahili
                            ? 'Imelandanishwa mtandaoni'
                            : 'Synced to cloud')
                        : (isSwahili
                            ? 'Imehifadhiwa ndani (Inasubiri mtandao)'
                            : 'Local draft (Pending sync)'),
                    child: Icon(
                      invoice.isSynced
                          ? Icons.check_circle_rounded
                          : Icons.access_time_rounded,
                      size: 13,
                      color: invoice.isSynced
                          ? AppColors.success
                          : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.customerName.isEmpty
                    ? loc.invoiceWalkIn
                    : invoice.customerName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.resolveTextPrimary(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  '${isSwahili ? "Mwisho" : "Due"}: ${dateFmt.format(invoice.dueDate.toLocal())}',
                  if (invoice.referenceNumber != null &&
                      invoice.referenceNumber!.trim().isNotEmpty)
                    'Ref: ${invoice.referenceNumber!.trim()}',
                ].join('  •  '),
                style: TextStyle(
                  color: overdue
                      ? AppColors.error
                      : AppColors.resolveTextSecondary(context),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(invoice.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              overdue && invoice.status != InvoiceStatus.paid
                  ? (isSwahili ? 'Imechelewa' : 'Overdue')
                  : invoiceStatusLabel(context, invoice.status),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: overdue && invoice.status != InvoiceStatus.paid
                    ? AppColors.error
                    : invoiceStatusColor(context, invoice.status),
              ),
            ),
          ],
        ),
        onTap: () => context.push(Routes.invoiceDetail(invoice.id)),
      ),
    );
  }
}

String invoiceStatusLabel(BuildContext context, InvoiceStatus status) {
  final loc = context.loc;
  return switch (status) {
    InvoiceStatus.unpaid => loc.invoiceStatusUnpaid,
    InvoiceStatus.partiallyPaid => loc.invoiceStatusPartial,
    InvoiceStatus.paid => loc.invoiceStatusPaid,
    InvoiceStatus.voided => loc.invoiceStatusVoid,
  };
}

Color invoiceStatusColor(BuildContext context, InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.unpaid => AppColors.resolveTextSecondary(context),
    InvoiceStatus.partiallyPaid => AppColors.warning,
    InvoiceStatus.paid => AppColors.success,
    InvoiceStatus.voided => AppColors.resolveTextTertiary(context),
  };
}
