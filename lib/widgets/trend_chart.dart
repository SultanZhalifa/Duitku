import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// A smooth line chart of monthly expense totals over time.
///
/// [data] is expected oldest → newest, as produced by
/// `ExpenseProvider.monthlyExpenseTrend`. Renders an empty state when every
/// month is zero (i.e. there's no real spending to plot).
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.data});

  final List<MapEntry<DateTime, double>> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = data.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    if (maxY == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No spending recorded in this period yet',
            style: TextStyle(color: scheme.outline),
          ),
        ),
      );
    }

    // Add headroom so the peak isn't glued to the top.
    final chartMax = maxY * 1.25;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: chartMax / 3,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    Formatters.compactCurrency(value),
                    style: TextStyle(color: scheme.outline, fontSize: 9),
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
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthAbbrev(data[i].key),
                      style: TextStyle(color: scheme.outline, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  Formatters.currency(s.y),
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppTheme.seed,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.seed,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).cardColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.seed.withValues(alpha: 0.28),
                    AppTheme.seed.withValues(alpha: 0.0),
                  ],
                ),
              ),
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].value),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthAbbrev(DateTime date) =>
      Formatters.shortMonthYear(date).split(' ').first;
}
