import 'package:flutter/material.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/format/money.dart';

class MoneyFlowCard extends StatelessWidget {
  const MoneyFlowCard({
    super.key,
    required this.startingBalance,
    required this.moneyIn,
    required this.moneyOut,
    required this.currentBalance,
    this.moneyInItems = const [],
    this.moneyOutItems = const [],
  });

  final double startingBalance;
  final double moneyIn;
  final double moneyOut;
  final double currentBalance;
  final List<MoneyFlowItem> moneyInItems;
  final List<MoneyFlowItem> moneyOutItems;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.reportsMoneyMovement,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.resolveTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            // Starting balance
            _FlowRow(
              label: loc.reportsStartingBalance,
              amount: startingBalance,
              color: AppColors.resolveTextSecondary(context),
            ),
            const SizedBox(height: 12),
            // Money In
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _FlowRow(
                    label: loc.reportsMoneyIn,
                    amount: moneyIn,
                    color: AppColors.success,
                    isBold: true,
                  ),
                  if (moneyInItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...moneyInItems.map((item) => Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _FlowRow(
                            label: item.label,
                            amount: item.amount,
                            color: AppColors.resolveTextSecondary(context),
                            fontSize: 13,
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Money Out
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _FlowRow(
                    label: loc.reportsMoneyOut,
                    amount: -moneyOut,
                    color: AppColors.error,
                    isBold: true,
                  ),
                  if (moneyOutItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...moneyOutItems.map((item) => Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _FlowRow(
                            label: item.label,
                            amount: -item.amount,
                            color: AppColors.resolveTextSecondary(context),
                            fontSize: 13,
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const Divider(height: 24),
            // Current balance
            _FlowRow(
              label: loc.reportsCurrentBalance,
              amount: currentBalance,
              color: AppColors.primary,
              isBold: true,
              fontSize: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.label,
    required this.amount,
    required this.color,
    this.isBold = false,
    this.fontSize = 14,
  });

  final String label;
  final double amount;
  final Color color;
  final bool isBold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
        Text(
          formatMoney(amount.abs()),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class MoneyFlowItem {
  const MoneyFlowItem({required this.label, required this.amount});
  final String label;
  final double amount;
}
