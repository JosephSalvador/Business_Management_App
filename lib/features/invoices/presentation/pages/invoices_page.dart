import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';
import '../../application/invoices_controller.dart';
import '../../domain/invoice.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.invoicesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: loc.invoicesAdd,
            onPressed: () => context.push(Routes.invoiceNew),
          ),
        ],
      ),
      body: WaveBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchBar(
                controller: _searchController,
                hintText: loc.invoicesSearch,
                onChanged: _onSearchChanged,
              ),
            ),
            _StatusFilters(state: state),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(InvoicesState state) {
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
                  final name = (inv.customerName ?? '').toLowerCase();
                  final amount = inv.totalAmount.toString();
                  return num.contains(_filter) ||
                      name.contains(_filter) ||
                      amount.contains(_filter);
                }).toList();

          if (filtered.isEmpty) {
            if (_filter.isNotEmpty) {
              return Center(
                child: Text(
                  'Hakuna ankara iliyopatikana kwa "$_filter"',
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

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(invoicesControllerProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _InvoiceTile(invoice: filtered[index]),
            ),
          );
        }(),
    };
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
  const _InvoiceTile({required this.invoice});

  final CustomerInvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final overdue = invoice.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          invoice.number,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          invoice.customerId == null
              ? loc.invoiceWalkIn
              : invoice.customerLabel,
          style: TextStyle(
            color: overdue
                ? AppColors.error
                : AppColors.resolveTextSecondary(context),
            fontSize: 13,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatMoney(invoice.totalAmount)),
            const SizedBox(height: 2),
            Text(
              invoiceStatusLabel(context, invoice.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: invoiceStatusColor(context, invoice.status),
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
