import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class ReportPieChart extends StatelessWidget {
  const ReportPieChart({
    super.key,
    required this.segments,
    this.height = 200,
    this.showLegend = true,
  });

  final List<PieChartSegment> segments;
  final double height;
  final bool showLegend;

  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.warning,
    AppColors.error,
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data',
              style: TextStyle(color: AppColors.resolveTextTertiary(context))),
        ),
      );
    }

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: height * 0.25,
              sections: segments.asMap().entries.map((entry) {
                final color = _colors[entry.key % _colors.length];
                final percent =
                    total > 0 ? (entry.value.value / total * 100) : 0.0;
                return PieChartSectionData(
                  color: color,
                  value: entry.value.value,
                  title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  radius: height * 0.35,
                );
              }).toList(),
            ),
          ),
        ),
        if (showLegend && segments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: segments.asMap().entries.map((entry) {
              final color = _colors[entry.key % _colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.value.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolveTextSecondary(context),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class PieChartSegment {
  const PieChartSegment({required this.label, required this.value});
  final String label;
  final double value;
}
