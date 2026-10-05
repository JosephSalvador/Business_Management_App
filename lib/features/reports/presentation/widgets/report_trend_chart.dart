import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/design_system/app_colors.dart';

class ReportTrendChart extends StatelessWidget {
  const ReportTrendChart({
    super.key,
    required this.dataPoints,
    this.lineColor,
    this.gradientColors,
    this.height = 200,
  });

  final List<ReportTrendDataPoint> dataPoints;
  final Color? lineColor;
  final List<Color>? gradientColors;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(color: AppColors.resolveTextTertiary(context)),
          ),
        ),
      );
    }

    final color = lineColor ?? AppColors.primary;
    final gradient = gradientColors ??
        [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ];

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calculateInterval(),
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.resolveTextTertiary(context)
                    .withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: _calculateBottomInterval(),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= dataPoints.length) {
                      return const SizedBox.shrink();
                    }
                    final label = dataPoints[index].label;
                    // Show short label
                    final shortLabel =
                        label.length > 5 ? label.substring(5, 10) : label;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        shortLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.resolveTextTertiary(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: dataPoints.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.value);
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: color,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: dataPoints.length <= 14,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: color,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final label = index < dataPoints.length
                        ? dataPoints[index].label
                        : '';
                    return LineTooltipItem(
                      '${_formatValue(spot.y)}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateInterval() {
    if (dataPoints.isEmpty) return 1;
    final max = dataPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    if (max <= 0) return 1;
    return (max / 4).ceilToDouble();
  }

  double _calculateBottomInterval() {
    if (dataPoints.length <= 7) return 1;
    return (dataPoints.length / 7).ceilToDouble();
  }

  String _formatValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

class ReportTrendDataPoint {
  const ReportTrendDataPoint({required this.label, required this.value});
  final String label;
  final double value;
}
