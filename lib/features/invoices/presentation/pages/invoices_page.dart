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
import '../../application/delivery_notes_controller.dart';
import '../../application/document_template_controller.dart';
import '../../application/invoices_controller.dart';
import '../../domain/delivery_note.dart';
import '../../domain/document_template.dart';
import '../../domain/invoice.dart';
import '../widgets/invoice_branding_sheet.dart';
import 'invoice_preview_screen.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/data/organization_providers.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _dnSearchController = TextEditingController();
  Timer? _debounce;
  Timer? _dnDebounce;
  String _filter = '';
  String _dnFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.index == 1) {
        ref.read(deliveryNotesControllerProvider.notifier).load();
      }
    });
    ref.read(invoicesControllerProvider.notifier).load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dnDebounce?.cancel();
    _searchController.dispose();
    _dnSearchController.dispose();
    _tabController.dispose();
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
    final orgState = ref.watch(settingsControllerProvider);
    final tplState = ref.watch(documentTemplateControllerProvider);
    final orgPrefix =
        orgState is SettingsLoaded ? orgState.organization.invoicePrefix : null;
    final tplPrefix = tplState.currentInvoiceConfiguration.invoicePrefix;
    final invoicePrefix = (orgPrefix != null && orgPrefix.trim().isNotEmpty)
        ? orgPrefix
        : tplPrefix;
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long, size: 18),
              text: isSw ? 'Ankara za Mauzo' : 'Sales Invoices',
            ),
            Tab(
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              text: isSw ? 'Waraka wa Mzigo' : 'Delivery Notes',
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.invoiceNew),
              icon: const Icon(Icons.add),
              label: Text(loc.invoicesAdd),
            )
          : null,
      body: WaveBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Invoices
            Column(
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
                Expanded(child: _buildBody(state, isSw, invoicePrefix)),
              ],
            ),
            // Tab 2: Delivery Notes
            _buildDeliveryNotesTab(context, isSw),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      InvoicesState state, bool isSwahili, String? invoicePrefix) {
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
                  final num = inv.displayNumber(invoicePrefix).toLowerCase();
                  final origNum = inv.number.toLowerCase();
                  final name = (inv.customerName ?? '').toLowerCase();
                  final refNo = (inv.referenceNumber ?? '').toLowerCase();
                  final amount = inv.totalAmount.toString();
                  return num.contains(_filter) ||
                      origNum.contains(_filter) ||
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
                  invoicePrefix: invoicePrefix,
                );
              },
            ),
          );
        }(),
    };
  }

  Widget _buildDeliveryNotesTab(BuildContext context, bool isSw) {
    final dnState = ref.watch(deliveryNotesControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppSearchBar(
            controller: _dnSearchController,
            hintText: isSw
                ? 'Tafuta kwa namba, mteja, msafirishaji...'
                : 'Search note #, customer, carrier...',
            onChanged: (val) {
              setState(() => _dnFilter = val.trim().toLowerCase());
              _dnDebounce?.cancel();
              _dnDebounce = Timer(const Duration(milliseconds: 350), () {
                ref
                    .read(deliveryNotesControllerProvider.notifier)
                    .load(search: val.trim(), silent: true);
              });
            },
          ),
        ),
        _DeliveryNoteStatusFilters(
          selectedStatus:
              dnState is DeliveryNotesLoaded ? dnState.status : null,
          onSelect: (st) => ref
              .read(deliveryNotesControllerProvider.notifier)
              .toggleStatus(st),
          isSwahili: isSw,
        ),
        Expanded(
          child: _buildDeliveryNotesList(context, dnState, isSw),
        ),
      ],
    );
  }

  Widget _buildDeliveryNotesList(
    BuildContext context,
    DeliveryNotesState state,
    bool isSw,
  ) {
    return switch (state) {
      DeliveryNotesLoading() =>
        const Center(child: CircularProgressIndicator()),
      DeliveryNotesFailure(:final message) => Center(
          child: Text(
            message,
            style: TextStyle(color: AppColors.resolveTextSecondary(context)),
          ),
        ),
      DeliveryNotesLoaded(:final items) => () {
          final filtered = _dnFilter.isEmpty
              ? items
              : items.where((dn) {
                  final num = dn.number.toLowerCase();
                  final name = dn.customerName.toLowerCase();
                  final carrier = (dn.carrierName ?? '').toLowerCase();
                  final vehicle = (dn.vehicleNumber ?? '').toLowerCase();
                  return num.contains(_dnFilter) ||
                      name.contains(_dnFilter) ||
                      carrier.contains(_dnFilter) ||
                      vehicle.contains(_dnFilter);
                }).toList();

          if (filtered.isEmpty) {
            if (_dnFilter.isNotEmpty) {
              return Center(
                child: Text(
                  isSw
                      ? 'Hakuna waraka uliopatikana kwa "$_dnFilter"'
                      : 'No delivery notes found matching "$_dnFilter"',
                  style: TextStyle(
                      color: AppColors.resolveTextSecondary(context)),
                ),
              );
            }
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: isSw
                  ? 'Hakuna Waraka wa Usafirishaji'
                  : 'No Delivery Notes Generated',
              message: isSw
                  ? 'Mihuri na nyaraka zote za usafirishaji zitaonekana hapa ukizitoa kwenye ankara.'
                  : 'All generated delivery notes will appear here once issued from an invoice.',
              actionLabel: isSw ? 'Tazama Ankara' : 'View Invoices',
              onAction: () => _tabController.animateTo(0),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(deliveryNotesControllerProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSw
                              ? 'Jumla ya Waraka: ${filtered.length}'
                              : 'Total Delivery Notes: ${filtered.length}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.resolveTextSecondary(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSw ? 'USAFIRISHAJI' : 'LOGISTICS DISPATCH',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D9488),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final note = filtered[index - 1];
                return _DeliveryNoteCard(note: note, isSwahili: isSw);
              },
            ),
          );
        }(),
    };
  }
}

class _DeliveryNoteStatusFilters extends StatelessWidget {
  const _DeliveryNoteStatusFilters({
    required this.selectedStatus,
    required this.onSelect,
    required this.isSwahili,
  });

  final DeliveryNoteStatus? selectedStatus;
  final ValueChanged<DeliveryNoteStatus> onSelect;
  final bool isSwahili;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          FilterChip(
            selected: selectedStatus == null,
            label: Text(isSwahili ? 'Zote' : 'All'),
            onSelected: (_) {
              if (selectedStatus != null) {
                onSelect(selectedStatus!);
              }
            },
          ),
          const SizedBox(width: 6),
          for (final st in DeliveryNoteStatus.values) ...[
            FilterChip(
              selected: selectedStatus == st,
              label: Text(_statusLabel(st, isSwahili)),
              onSelected: (_) => onSelect(st),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  String _statusLabel(DeliveryNoteStatus st, bool isSw) {
    switch (st) {
      case DeliveryNoteStatus.draft:
        return isSw ? 'Rasimu' : 'Draft';
      case DeliveryNoteStatus.dispatched:
        return isSw ? 'Zilizosafirishwa' : 'Dispatched';
      case DeliveryNoteStatus.delivered:
        return isSw ? 'Zilizowasilishwa' : 'Delivered';
      case DeliveryNoteStatus.cancelled:
        return isSw ? 'Zilizofutwa' : 'Cancelled';
    }
  }
}

class _DeliveryNoteCard extends ConsumerWidget {
  const _DeliveryNoteCard({
    required this.note,
    required this.isSwahili,
  });

  final DeliveryNoteSummary note;
  final bool isSwahili;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(note.issueDate);

    Color statusColor;
    String statusLabel;
    switch (note.status) {
      case DeliveryNoteStatus.draft:
        statusColor = const Color(0xFFD97706);
        statusLabel = isSwahili ? 'Rasimu' : 'Draft';
        break;
      case DeliveryNoteStatus.dispatched:
        statusColor = const Color(0xFF0D9488);
        statusLabel = isSwahili ? 'Imesafirishwa' : 'Dispatched';
        break;
      case DeliveryNoteStatus.delivered:
        statusColor = const Color(0xFF059669);
        statusLabel = isSwahili ? 'Imewasilishwa' : 'Delivered';
        break;
      case DeliveryNoteStatus.cancelled:
        statusColor = const Color(0xFFDC2626);
        statusLabel = isSwahili ? 'Imefutwa' : 'Cancelled';
        break;
    }

    void openPreview() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InvoicePreviewScreen(
            documentId: note.id,
            documentNumber: note.number,
            documentType: DocumentType.deliveryNote,
          ),
        ),
      );
    }

    Future<void> showDispatchDialog() async {
      final driverController = TextEditingController(text: note.driverName ?? '');
      final phoneController = TextEditingController(text: note.driverPhone ?? '');
      final vehicleController = TextEditingController(text: note.vehicleNumber ?? '');
      final carrierController = TextEditingController(text: note.carrierName ?? '');

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili ? 'Safirisha Mzigo' : 'Dispatch Delivery Note',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      note.number,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: driverController,
                  decoration: InputDecoration(
                    labelText: isSwahili ? 'Jina la Dereva' : 'Driver Name',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isSwahili ? 'Namba ya Simu ya Dereva' : 'Driver Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleController,
                  decoration: InputDecoration(
                    labelText: isSwahili ? 'Namba ya Chombo / Gari' : 'Vehicle Plate / Reg No',
                    prefixIcon: const Icon(Icons.directions_car_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: carrierController,
                  decoration: InputDecoration(
                    labelText: isSwahili ? 'Kampuni ya Usafirishaji (Si lazima)' : 'Carrier / Transporter (Optional)',
                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(isSwahili ? 'Ghairi' : 'Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await ref.read(deliveryNotesControllerProvider.notifier).dispatch(
                    note.id,
                    driverName: driverController.text.trim().isEmpty ? null : driverController.text.trim(),
                    driverPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    vehicleNumber: vehicleController.text.trim().isEmpty ? null : vehicleController.text.trim(),
                    carrierName: carrierController.text.trim().isEmpty ? null : carrierController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSwahili
                              ? 'Mzigo umethibitishwa kusafirishwa!'
                              : 'Delivery note marked as dispatched!',
                        ),
                        backgroundColor: const Color(0xFF0D9488),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hitilafu: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 16),
              label: Text(isSwahili ? 'Thibitisha Kusafirisha' : 'Confirm Dispatch'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            ),
          ],
        ),
      );
    }

    Future<void> showDeliverDialog() async {
      final recipientController = TextEditingController(text: note.customerName);

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSwahili ? 'Thibitisha Kupokelewa' : 'Confirm Delivery',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      note.number,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSwahili
                    ? 'Mzigo huu umewasilishwa kwa mteja salama? Weka jina la aliyepokea mzigo.'
                    : 'Has this consignment been successfully handed over? Enter recipient name.',
                style: TextStyle(fontSize: 13, color: AppColors.resolveTextSecondary(context)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: recipientController,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Jina la Mpokeaji' : 'Recipient Name',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(isSwahili ? 'Ghairi' : 'Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await ref.read(deliveryNotesControllerProvider.notifier).deliver(
                    note.id,
                    recipientName: recipientController.text.trim().isEmpty ? null : recipientController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSwahili
                              ? 'Mzigo umethibitishwa kupokelewa kikamilifu!'
                              : 'Delivery completed successfully!',
                        ),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hitilafu: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(isSwahili ? 'Thibitisha Kupokea' : 'Confirm Received'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            ),
          ],
        ),
      );
    }

    Future<void> showCancelDialog() async {
      final reasonController = TextEditingController();

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isSwahili ? 'Ghairi Hati ya Mzigo?' : 'Cancel Delivery Note?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSwahili
                    ? 'Je, una uhakika unataka kughairi hati hii (${note.number})? Hatua hii haiwezi kurudishwa.'
                    : 'Are you sure you want to cancel delivery note ${note.number}? This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: AppColors.resolveTextSecondary(context)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: isSwahili ? 'Sababu ya kughairi' : 'Cancellation reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(isSwahili ? 'Hapana' : 'No'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await ref.read(deliveryNotesControllerProvider.notifier).cancel(
                    note.id,
                    reason: reasonController.text.trim().isEmpty ? 'Cancelled by user' : reasonController.text.trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSwahili ? 'Hati ya mzigo imeghairiwa.' : 'Delivery note cancelled.',
                        ),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hitilafu: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: Text(isSwahili ? 'Ndiyo, Ghairi' : 'Yes, Cancel'),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.resolveBorder(context),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: openPreview,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Number, Status badge, and Sync icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      size: 20,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.number,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.resolveTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.resolveTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    note.isSynced
                        ? Icons.cloud_done_outlined
                        : Icons.access_time_rounded,
                    size: 16,
                    color: note.isSynced
                        ? const Color(0xFF059669)
                        : AppColors.resolveTextSecondary(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Customer Name
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 15,
                    color: AppColors.resolveTextSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppColors.resolveTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (note.carrierName != null || note.vehicleNumber != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 15,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      [
                        if (note.carrierName != null) note.carrierName,
                        if (note.vehicleNumber != null) note.vehicleNumber,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // Bottom Row: Items count, Status Actions, and View & Print button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: AppColors.resolveTextSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSwahili
                            ? '${note.itemCount} bidhaa'
                            : '${note.itemCount} items',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.resolveTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (note.status == DeliveryNoteStatus.draft)
                        FilledButton.icon(
                          onPressed: showDispatchDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.local_shipping_outlined, size: 14),
                          label: Text(
                            isSwahili ? 'Safirisha' : 'Dispatch',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (note.status == DeliveryNoteStatus.dispatched)
                        FilledButton.icon(
                          onPressed: showDeliverDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 14),
                          label: Text(
                            isSwahili ? 'Imefika' : 'Delivered',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 6),
                      FilledButton.tonalIcon(
                        onPressed: openPreview,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.print_outlined, size: 14),
                        label: Text(
                          isSwahili ? 'Tazama' : 'Preview',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                      if (note.status != DeliveryNoteStatus.delivered &&
                          note.status != DeliveryNoteStatus.cancelled) ...[
                        const SizedBox(width: 2),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: isSwahili ? 'Chaguzi' : 'Options',
                          onSelected: (val) {
                            if (val == 'dispatch') showDispatchDialog();
                            if (val == 'deliver') showDeliverDialog();
                            if (val == 'cancel') showCancelDialog();
                          },
                          itemBuilder: (_) => [
                            if (note.status == DeliveryNoteStatus.draft)
                              PopupMenuItem(
                                value: 'dispatch',
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_shipping_outlined,
                                        size: 16, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 8),
                                    Text(isSwahili ? 'Safirisha Mzigo' : 'Dispatch Consignment'),
                                  ],
                                ),
                              ),
                            if (note.status == DeliveryNoteStatus.dispatched)
                              PopupMenuItem(
                                value: 'deliver',
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 16, color: Color(0xFF059669)),
                                    const SizedBox(width: 8),
                                    Text(isSwahili ? 'Thibitisha Kufika' : 'Confirm Delivery'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  const Icon(Icons.cancel_outlined,
                                      size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSwahili ? 'Ghairi Hati' : 'Cancel Delivery Note',
                                    style: const TextStyle(color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? const Color(0xFF334155) : AppColors.resolveBorder(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B)
            : AppColors.resolveCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.resolveBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              context,
              isSwahili ? 'Jumla ya Ankara' : 'Total Billed',
              formatMoney(totalBilled),
              AppColors.resolveTextPrimary(context),
            ),
          ),
          Container(width: 1, height: 28, color: dividerColor),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              context,
              isSwahili ? 'Kilicholipwa' : 'Collected',
              formatMoney(collected),
              isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            ),
          ),
          Container(width: 1, height: 28, color: dividerColor),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              context,
              isSwahili ? 'Salio (Deni)' : 'Outstanding',
              formatMoney(totalOutstanding),
              isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.resolveTextSecondary(context),
          ),
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
          final isSelected = selected == status;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            selectedColor: AppColors.primaryContainer,
            backgroundColor: AppColors.resolveCardBackground(context),
            checkmarkColor: AppColors.primary,
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.resolveBorder(context),
            ),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.resolveTextPrimary(context),
            ),
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
    this.invoicePrefix,
  });

  final CustomerInvoiceSummary invoice;
  final bool isSwahili;
  final String? invoicePrefix;

  @override
  Widget build(BuildContext context) {
    final overdue = invoice.isOverdue;
    final dateFmt = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 0.5,
      color: AppColors.resolveCardBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.resolveBorder(context)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                invoice.documentTitle.toUpperCase(),
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : Theme.of(context).colorScheme.primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      invoice.displayNumber(invoicePrefix),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.resolveTextPrimary(context),
                        fontSize: 14,
                      ),
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
                          : AppColors.resolveTextSecondary(context),
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
                invoice.customerLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.resolveTextPrimary(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (invoice.dueDate != null)
                    '${isSwahili ? "Mwisho" : "Due"}: ${dateFmt.format(invoice.dueDate!.toLocal())}',
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
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.resolveTextPrimary(context),
              ),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    InvoiceStatus.unpaid =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    InvoiceStatus.partiallyPaid => AppColors.warning,
    InvoiceStatus.paid => AppColors.success,
    InvoiceStatus.voided => AppColors.resolveTextTertiary(context),
  };
}
