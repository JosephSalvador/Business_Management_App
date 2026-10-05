import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class ReportKpiCard extends StatelessWidget {
  const ReportKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.changePercent,
    this.isPositive,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String value;
  final double? changePercent;
  final bool? isPositive;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon,
                        size: 18, color: iconColor ?? AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.resolveTextPrimary(context),
                ),
              ),
            ),
            if (changePercent != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    (isPositive ?? true)
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 14,
                    color: (isPositive ?? true)
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${changePercent!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (isPositive ?? true)
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
