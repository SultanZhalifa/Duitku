import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/formatters.dart';

/// A donut chart of spending by category, with a side legend showing each
/// category's share. Renders an empty-state message when there's no spending.
class SpendingChart extends StatefulWidget {
  const SpendingChart({super.key, required this.data});

  /// Category → total expense, expected pre-sorted high → low.
  final List<MapEntry<Category, double>> data;

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart_outline,
                  size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'No spending yet this month',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    final total = widget.data.fold<double>(0, (sum, e) => sum + e.value);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 44,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: [
                for (var i = 0; i < widget.data.length; i++)
                  _section(i, widget.data[i], total),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.data.length; i++)
                _LegendRow(
                  entry: widget.data[i],
                  percent: total == 0 ? 0 : widget.data[i].value / total,
                  highlighted: i == _touchedIndex,
                ),
            ],
          ),
        ),
      ],
    );
  }

  PieChartSectionData _section(
    int index,
    MapEntry<Category, double> entry,
    double total,
  ) {
    final isTouched = index == _touchedIndex;
    final percent = total == 0 ? 0.0 : entry.value / total;
    return PieChartSectionData(
      value: entry.value,
      color: entry.key.color,
      radius: isTouched ? 30 : 24,
      showTitle: isTouched,
      title: '${(percent * 100).toStringAsFixed(0)}%',
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.entry,
    required this.percent,
    required this.highlighted,
  });

  final MapEntry<Category, double> entry;
  final double percent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final category = entry.key;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: category.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  Formatters.currency(entry.value),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(percent * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: category.color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
