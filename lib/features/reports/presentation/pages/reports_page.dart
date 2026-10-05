import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900
        ? 4
        : width > 600
            ? 3
            : 2;

    return Scaffold(
      appBar: AppBar(title: Text(loc.reportsHubTitle)),
      body: WaveBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.reportsBusinessOverview,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              // Business Overview card (full width)
              _ReportCard(
                title: loc.reportsBusinessOverview,
                subtitle: 'Sales, Profit, Expenses, Money',
                icon: Icons.dashboard,
                color: AppColors.primary,
                onTap: () => context.push(Routes.reportsOverview),
              ),
              const SizedBox(height: 16),
              Text(
                'Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              // Report grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _ReportCard(
                      title: loc.reportsSales,
                      subtitle: loc.reportsSalesPerformance,
                      icon: Icons.store,
                      color: AppColors.primary,
                      onTap: () => context.push(Routes.reportsSales),
                    ),
                    _ReportCard(
                      title: loc.reportsStock,
                      subtitle: loc.reportsStockOverview,
                      icon: Icons.inventory_2,
                      color: AppColors.secondary,
                      onTap: () => context.push(Routes.reportsStock),
                    ),
                    _ReportCard(
                      title: loc.reportsMoney,
                      subtitle: loc.reportsMoneyMovement,
                      icon: Icons.account_balance_wallet,
                      color: AppColors.warning,
                      onTap: () => context.push(Routes.reportsMoney),
                    ),
                    _ReportCard(
                      title: loc.reportsPurchasesReport,
                      subtitle: loc.reportsPurchasesOverview,
                      icon: Icons.shopping_cart,
                      color: AppColors.success,
                      onTap: () => context.push(Routes.reportsPurchases),
                    ),
                    _ReportCard(
                      title: loc.reportsExpensesReport,
                      subtitle: loc.reportsExpensesOverview,
                      icon: Icons.receipt_long,
                      color: AppColors.error,
                      onTap: () => context.push(Routes.reportsExpenses),
                    ),
                    _ReportCard(
                      title: loc.reportsTopProducts,
                      subtitle: loc.reportsSeeAll,
                      icon: Icons.leaderboard,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.push(Routes.reportsTopProducts),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.resolveTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.resolveTextTertiary(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
