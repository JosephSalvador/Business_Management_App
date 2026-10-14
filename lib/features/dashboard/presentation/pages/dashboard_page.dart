import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/loc.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../../core/network/connectivity_monitor.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/design_system/responsive.dart';
import '../../../../shared/format/money.dart';
import '../../application/dashboard_controller.dart';
import '../widgets/revenue_line_chart.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedPeriod = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadForPeriod());
  }

  int _trendDaysForPeriod() {
    switch (_selectedPeriod) {
      case 0:
        return 1;
      case 1:
        return 7;
      case 2:
        return 30;
      case 3:
        return 30;
      default:
        return 30;
    }
  }

  void _loadForPeriod() {
    ref
        .read(dashboardControllerProvider.notifier)
        .refresh(trendDays: _trendDaysForPeriod());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final connection = ref.watch(connectionQualityProvider);

    final userName = auth is AuthAuthenticated
        ? auth.session.user.fullName.split(' ').first
        : '';

    return Scaffold(
      body: state is DashboardLoading
          ? const Center(child: CircularProgressIndicator())
          : state is DashboardFailure
              ? _ErrorView(
                  message: state.message,
                  onRetry: _loadForPeriod,
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadForPeriod(),
                  child: _DashboardBody(
                    state: state as DashboardLoaded,
                    selectedPeriod: _selectedPeriod,
                    onPeriodChanged: (i) {
                      setState(() => _selectedPeriod = i);
                      _loadForPeriod();
                    },
                    userName: userName,
                    connectionQuality: connection,
                  ),
                ),
    );
  }
}

// ── Dashboard Body ────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.state,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.userName,
    required this.connectionQuality,
  });

  final DashboardLoaded state;
  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;
  final String userName;
  final ConnectionQuality connectionQuality;

  List<SalesTrendPoint> _filteredTrend() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (selectedPeriod == 0) {
      return state.trendData;
    }
    return state.trendData.where((p) {
      try {
        final d = DateTime.parse(p.label);
        final day = DateTime(d.year, d.month, d.day);
        switch (selectedPeriod) {
          case 1:
            return day.isAfter(today.subtract(const Duration(days: 8)));
          case 2:
            return day.isAfter(today.subtract(const Duration(days: 31)));
          case 3:
            return day.month == now.month && day.year == now.year;
        }
      } catch (_) {}
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isDesktop = Responsive.isDesktop(context);
    final padding = Responsive.getPagePadding(context);
    final trend = _filteredTrend();
    final revenue = trend.fold<double>(0, (s, p) => s + p.revenue);
    final transactions = trend.fold<int>(0, (s, p) => s + p.saleCount);

    return ListView(
      padding: padding,
      children: [
        if (state.isFromCache) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.resolveCardBackground(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.resolveOutline(context).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.dashboardCachedBanner,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _GreetingHeader(
            userName: userName, connectionQuality: connectionQuality),
        const SizedBox(height: 20),
        _PeriodSelector(
          selected: selectedPeriod,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 16),
        if (isDesktop)
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: loc.dashboardRevenueLabel,
                  value: formatMoney(revenue),
                  icon: Icons.attach_money_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: loc.dashboardTransactionsLabel,
                  value: '$transactions',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  label: loc.dashboardTotalProducts,
                  value: '${state.summary.totalProducts}',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: loc.dashboardRevenueLabel,
                      value: formatMoney(revenue),
                      icon: Icons.attach_money_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: loc.dashboardTransactionsLabel,
                      value: '$transactions',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _KpiCard(
                label: loc.dashboardTotalProducts,
                value: '${state.summary.totalProducts}',
                icon: Icons.inventory_2_outlined,
                color: AppColors.warning,
              ),
            ],
          ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: loc.dashboardRevenueTrend,
          trailing: Text(
            _periodLabel(loc),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.resolveTextTertiary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RevenueLineChart(dataPoints: trend),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: loc.dashboardQuickActions),
        const SizedBox(height: 12),
        _QuickActions(loc: loc),
        const SizedBox(height: 24),
        if (state.topProducts.isNotEmpty) ...[
          _SectionHeader(title: loc.dashboardTopProducts),
          const SizedBox(height: 12),
          _TopProductsList(products: state.topProducts, loc: loc),
          const SizedBox(height: 24),
        ],
        if (state.lowStock.isNotEmpty) ...[
          _SectionHeader(
            title: loc.dashboardLowStockAlert,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.lowStock.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LowStockCards(items: state.lowStock, loc: loc),
          const SizedBox(height: 24),
        ],
        if (state.recentActivity.isNotEmpty) ...[
          _SectionHeader(title: loc.dashboardRecentActivity),
          const SizedBox(height: 12),
          _ActivityFeed(items: state.recentActivity, loc: loc),
          const SizedBox(height: 24),
        ],
        if (state.lowStock.isEmpty && state.recentActivity.isEmpty)
          _EmptyDashboard(loc: loc),
        const SizedBox(height: 32),
      ],
    );
  }

  String _periodLabel(AppLocalizations loc) {
    switch (selectedPeriod) {
      case 0:
        return loc.dashboardPeriodToday;
      case 1:
        return loc.dashboardDays7;
      case 2:
        return loc.dashboardDays30;
      case 3:
        return loc.dashboardPeriodThisMonth;
      default:
        return '';
    }
  }
}

// ── Greeting Header ──────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader(
      {required this.userName, required this.connectionQuality});
  final String userName;
  final ConnectionQuality connectionQuality;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? loc.dashboardGreetingMorning
        : hour < 17
            ? loc.dashboardGreetingAfternoon
            : loc.dashboardGreetingEvening;
    final name = userName.isNotEmpty ? ', $userName' : '';
    final dateStr =
        DateFormat('EEE, d MMM', Localizations.localeOf(context).languageCode)
            .format(DateTime.now());

    final isOnline = connectionQuality == ConnectionQuality.online;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$greeting$name 👋',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.resolveTextPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.success : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.resolveTextTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const NotificationBellButton(),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Period Selector ──────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final labels = [
      loc.dashboardPeriodDay,
      loc.dashboardPeriodWeek,
      loc.dashboardPeriodMonth,
      loc.dashboardPeriodYear,
    ];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.resolveTextSecondary(context),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.resolveTextPrimary(context),
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.resolveTextSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.resolveTextPrimary(context),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(Icons.point_of_sale_rounded, loc.dashboardSellNow,
          AppColors.primary, () => context.push('/pos')),
      _ActionData(Icons.person_add_alt_1_rounded, loc.dashboardAddCustomer,
          AppColors.secondary, () => context.push('/customers/new')),
      _ActionData(Icons.receipt_long_rounded, loc.dashboardAddExpense,
          AppColors.warning, () => context.push('/expenses/new')),
      _ActionData(Icons.shopping_cart_rounded, loc.dashboardAddPurchase,
          AppColors.success, () => context.push('/purchases/new')),
      _ActionData(Icons.inventory_2_rounded, loc.dashboardViewStock,
          AppColors.primaryDark, () => context.go('/home?tab=1')),
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: 80,
          child: _ActionChip(data: actions[i]),
        ),
      ),
    );
  }
}

class _ActionData {
  const _ActionData(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.resolveTextSecondary(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Top Products ─────────────────────────────────────────────────

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.products, required this.loc});
  final List<Map<String, dynamic>> products;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++) ...[
            _TopProductTile(
              rank: i + 1,
              name: products[i]['productName'] ?? '',
              quantity: (products[i]['totalQuantity'] ?? 0).toDouble(),
              revenue: (products[i]['totalRevenue'] ?? 0).toDouble(),
              loc: loc,
            ),
            if (i < products.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({
    required this.rank,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.loc,
  });

  final int rank;
  final String name;
  final double quantity;
  final double revenue;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : AppColors.resolveTextTertiary(context);

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: medalColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: medalColor,
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.resolveTextPrimary(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        loc.dashboardUnitsSold(quantity.toInt()),
        style: TextStyle(
          fontSize: 12,
          color: AppColors.resolveTextTertiary(context),
        ),
      ),
      trailing: Text(
        formatMoney(revenue),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.resolveTextPrimary(context),
        ),
      ),
    );
  }
}

// ── Low Stock Cards ──────────────────────────────────────────────

class _LowStockCards extends StatelessWidget {
  const _LowStockCards({required this.items, required this.loc});
  final List<Map<String, dynamic>> items;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final name = item['productName'] ?? item['name'] ?? '';
        final qty = (item['quantity'] ?? 0).toDouble();
        final stockLevel = qty <= 0 ? 0.0 : (qty / 10).clamp(0.0, 1.0);

        final color = qty <= 0
            ? AppColors.error
            : qty <= 3
                ? AppColors.warning
                : AppColors.success;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  qty <= 0
                      ? Icons.inventory_2_rounded
                      : Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.resolveTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: stockLevel,
                        minHeight: 4,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qty <= 0
                          ? loc.dashboardOutOfStock
                          : loc.dashboardItemsRemaining(qty.toInt()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Activity Feed ────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.items, required this.loc});
  final List<Map<String, dynamic>> items;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ActivityTile(item: items[i], loc: loc),
            if (i < items.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.loc});
  final Map<String, dynamic> item;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final action = (item['action'] ?? '').toString().toLowerCase();
    final entityType = item['entityType'] ?? '';
    final entityName = item['entityName'] as String?;
    final amount = item['amount'] as num?;
    final status = item['status'] as String?;
    final occurredAt = item['occurredAt'] as String?;

    final iconData = _iconForEntityType(entityType);
    final color = _colorForAction(action, status);
    final timeAgo = _relativeTime(occurredAt);
    final description = _friendlyDescription(action, entityType, entityName);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(iconData, color: color, size: 20),
      ),
      title: Text(
        description,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.resolveTextPrimary(context),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(context, amount, status, action),
      trailing: timeAgo != null
          ? Text(
              timeAgo,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.resolveTextTertiary(context),
              ),
            )
          : null,
    );
  }

  Widget? _buildSubtitle(
      BuildContext context, num? amount, String? status, String action) {
    final parts = <String>[];
    if (amount != null && amount > 0) {
      parts.add(formatMoney(amount.toDouble()));
    }
    if (status != null && status.isNotEmpty) {
      parts.add(status);
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' • '),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: status == 'Paid'
            ? AppColors.success
            : status == 'Pending'
                ? AppColors.warning
                : status == 'Voided'
                    ? AppColors.error
                    : AppColors.resolveTextTertiary(context),
      ),
    );
  }

  IconData _iconForEntityType(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'sale':
        return Icons.point_of_sale_rounded;
      case 'product':
        return Icons.inventory_2_outlined;
      case 'customer':
        return Icons.person_outline_rounded;
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'purchase':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorForAction(String action, String? status) {
    if (status == 'Voided') return AppColors.error;
    if (action.contains('delete') || action.contains('remove')) {
      return AppColors.error;
    }
    if (action.contains('create') || action.contains('add')) {
      return AppColors.success;
    }
    if (action.contains('update') || action.contains('edit')) {
      return AppColors.primary;
    }
    return AppColors.primary;
  }

  String _friendlyDescription(
      String action, String entityType, String? entityName) {
    final entity = entityName ?? _entityLabel(entityType);
    if (action.contains('create') || action.contains('add')) {
      return loc.dashboardActivityAdded(entity);
    }
    if (action.contains('update') || action.contains('edit')) {
      return loc.dashboardActivityUpdated(entity);
    }
    if (action.contains('delete') || action.contains('remove')) {
      return loc.dashboardActivityDeleted(entity);
    }
    return loc.dashboardActivityDefault(action, entity);
  }

  String _entityLabel(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'sale':
        return 'Mauzo';
      case 'product':
        return 'Bidhaa';
      case 'customer':
        return 'Mteja';
      case 'expense':
        return 'Gharama';
      case 'purchase':
        return 'Ununuzi';
      default:
        return entityType;
    }
  }

  String? _relativeTime(String? isoDate) {
    if (isoDate == null) return null;
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'Sasa hivi';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
      if (diff.inHours < 24) return '${diff.inHours} saa';
      if (diff.inDays < 7) return '${diff.inDays} siku';
      return DateFormat('d/M').format(date);
    } catch (_) {
      return null;
    }
  }
}

// ── Empty Dashboard ──────────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.dashboard_customize_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.dashboardEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.resolveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.dashboardEmptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.resolveTextSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error View ──────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.error_outline,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.resolveTextSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(loc.dashboardTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
