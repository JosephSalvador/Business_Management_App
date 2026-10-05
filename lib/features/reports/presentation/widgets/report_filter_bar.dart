import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../data/report_filter.dart';

class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  final ReportFilter filter;
  final ValueChanged<ReportFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Period chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PeriodChip(
                  label: loc.reportsPeriodToday,
                  selected: filter.period == ReportPeriod.today,
                  onTap: () => onFilterChanged(
                    filter.copyWith(
                        period: ReportPeriod.today, clearCustomDates: true),
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: 'Yesterday',
                  selected: filter.period == ReportPeriod.yesterday,
                  onTap: () => onFilterChanged(
                    filter.copyWith(
                        period: ReportPeriod.yesterday, clearCustomDates: true),
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: loc.reportsPeriodThisWeek,
                  selected: filter.period == ReportPeriod.thisWeek,
                  onTap: () => onFilterChanged(
                    filter.copyWith(
                        period: ReportPeriod.thisWeek, clearCustomDates: true),
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: loc.reportsPeriodThisMonth,
                  selected: filter.period == ReportPeriod.thisMonth,
                  onTap: () => onFilterChanged(
                    filter.copyWith(
                        period: ReportPeriod.thisMonth, clearCustomDates: true),
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: loc.reportsPeriodLastMonth,
                  selected: filter.period == ReportPeriod.lastMonth,
                  onTap: () => onFilterChanged(
                    filter.copyWith(
                        period: ReportPeriod.lastMonth, clearCustomDates: true),
                  ),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: loc.reportsCustomRange,
                  selected: filter.period == ReportPeriod.custom,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 2),
                      lastDate: now,
                      initialDateRange: filter.period == ReportPeriod.custom
                          ? DateTimeRange(
                              start: filter.from ??
                                  now.subtract(const Duration(days: 30)),
                              end: filter.to ?? now,
                            )
                          : DateTimeRange(
                              start: now.subtract(const Duration(days: 30)),
                              end: now,
                            ),
                    );
                    if (picked != null) {
                      onFilterChanged(filter.copyWith(
                        period: ReportPeriod.custom,
                        from: picked.start,
                        to: picked.end.add(const Duration(
                            hours: 23, minutes: 59, seconds: 59)),
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
          // Date range display
          if (filter.period == ReportPeriod.custom &&
              filter.from != null &&
              filter.to != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${DateFormat('MMM d, yyyy').format(filter.from!)} — ${DateFormat('MMM d, yyyy').format(filter.to!)}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.resolveTextSecondary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
