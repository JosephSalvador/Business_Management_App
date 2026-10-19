import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/format/money.dart';

class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({required this.dataPoints, super.key});

  final List<SalesTrendPoint> dataPoints;

  bool get _hasData => dataPoints.any((p) => p.revenue > 0);

  @override
  Widget build(BuildContext context) {
    if (!_hasData) return _buildEmptyState();

    final spots = <FlSpot>[];
    final labels = <String>[];
    for (var i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].revenue));
      labels.add(_formatLabel(dataPoints[i].label));
    }

    final maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    final yInterval = _niceInterval(maxY);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _compact(value),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  final n = labels.length;
                  final showEvery = n <= 7
                      ? 1
                      : n <= 14
                          ? (n / 4).ceil()
                          : (n / 6).ceil();
                  if (idx % showEvery != 0 && idx != n - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[idx],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final p = dataPoints[spot.x.toInt()];
                  final dateStr = _formatFullDate(p.label);
                  return LineTooltipItem(
                    '$dateStr\n${formatMoney(p.revenue)}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchSpotThreshold: 20,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF0066FF),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 10,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF0066FF),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0066FF).withValues(alpha: 0.15),
                    const Color(0xFF0066FF).withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: maxY > 0 ? maxY * 1.3 : 100,
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded,
                size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Hakuna mauzo bado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Mwenendo wa mapato utaonekana hapa',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('d/M').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatFullDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat('d MMM yyyy', 'sw').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  static double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    final rough = maxY / 3;
    if (rough <= 2) return 2;
    if (rough <= 5) return 5;
    if (rough <= 10) return 10;
    if (rough <= 25) return 25;
    if (rough <= 50) return 50;
    if (rough <= 100) return 100;
    if (rough <= 250) return 250;
    if (rough <= 500) return 500;
    if (rough <= 1000) return 1000;
    if (rough <= 2500) return 2500;
    if (rough <= 5000) return 5000;
    if (rough <= 10000) return 10000;
    if (rough <= 25000) return 25000;
    if (rough <= 50000) return 50000;
    if (rough <= 100000) return 100000;
    if (rough <= 500000) return 500000;
    return (rough / 500000).ceilToDouble() * 500000;
  }
}

class SalesTrendPoint {
  const SalesTrendPoint({
    required this.label,
    required this.saleCount,
    required this.revenue,
  });

  final String label;
  final int saleCount;
  final double revenue;

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) {
    num parsedRevenue = 0;
    if (json['revenue'] is num) {
      parsedRevenue = json['revenue'] as num;
    } else if (json['revenue'] is String) {
      parsedRevenue = num.tryParse(json['revenue'] as String) ?? 0;
    }

    num parsedCount = 0;
    if (json['saleCount'] is num) {
      parsedCount = json['saleCount'] as num;
    } else if (json['saleCount'] is String) {
      parsedCount = num.tryParse(json['saleCount'] as String) ?? 0;
    }

    return SalesTrendPoint(
      label: json['label'] as String? ?? '',
      saleCount: parsedCount.toInt(),
      revenue: parsedRevenue.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'saleCount': saleCount,
        'revenue': revenue,
      };
}
