import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// A horizontal, scrollable strip of month pills. The selected month is
/// highlighted; tapping one notifies via [onSelected].
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.months,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected = month.year == selected.year &&
              month.month == selected.month;

          return GestureDetector(
            onTap: () => onSelected(month),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                Formatters.shortMonthYear(month),
                style: TextStyle(
                  color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
