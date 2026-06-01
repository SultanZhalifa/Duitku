import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/trend_chart.dart';

/// Statistics tab: a 6-month expense trend line chart plus headline figures
/// (busiest day, highest single expense, category leaderboard) — all computed
/// from real transactions for the selected month.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.isEmpty) {
      return const _StatsEmptyState();
    }

    final monthTx = provider.transactionsForSelectedMonth;
    final expenses = monthTx.where((t) => t.isExpense).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        _Card(
          title: '6-month expense trend',
          child: TrendChart(data: provider.monthlyExpenseTrend()),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Total spent',
                value: Formatters.currency(provider.expenseForMonth),
                icon: Icons.payments_outlined,
                color: AppTheme.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Transactions',
                value: '${monthTx.length}',
                icon: Icons.receipt_long_outlined,
                color: AppTheme.seed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _highestExpenseTile(context, expenses)),
            const SizedBox(width: 12),
            Expanded(child: _busiestDayTile(context, expenses)),
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Spending by category',
          child: _CategoryLeaderboard(
            data: provider.expenseByCategory,
            total: provider.expenseForMonth,
          ),
        ),
      ],
    );
  }

  Widget _highestExpenseTile(BuildContext context, List<Transaction> expenses) {
    if (expenses.isEmpty) {
      return const _StatTile(
        label: 'Highest expense',
        value: '—',
        icon: Icons.arrow_upward,
        color: AppTheme.warn,
      );
    }
    final highest =
        expenses.reduce((a, b) => a.amount >= b.amount ? a : b);
    return _StatTile(
      label: 'Highest: ${highest.title}',
      value: Formatters.currency(highest.amount),
      icon: Icons.arrow_upward,
      color: AppTheme.warn,
    );
  }

  Widget _busiestDayTile(BuildContext context, List<Transaction> expenses) {
    if (expenses.isEmpty) {
      return const _StatTile(
        label: 'Busiest day',
        value: '—',
        icon: Icons.calendar_today_outlined,
        color: AppTheme.income,
      );
    }
    // Sum expenses per calendar day, then pick the day with the highest total.
    final byDay = <DateTime, double>{};
    for (final t in expenses) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      byDay.update(day, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final busiest =
        byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _StatTile(
      label: 'Busiest: ${Formatters.dayLabel(busiest.key)}',
      value: Formatters.currency(busiest.value),
      icon: Icons.calendar_today_outlined,
      color: AppTheme.income,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLeaderboard extends StatelessWidget {
  const _CategoryLeaderboard({required this.data, required this.total});

  final List<MapEntry<Category, double>> data;
  final double total;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Text(
        'No expenses to break down this month.',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }
    return Column(
      children: [
        for (final entry in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(entry.key.icon, size: 16, color: entry.key.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text(
                      Formatters.currency(entry.value),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : entry.value / total,
                    minHeight: 6,
                    backgroundColor: entry.key.color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(entry.key.color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatsEmptyState extends StatelessWidget {
  const _StatsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('No statistics yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add a few transactions and your trends will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
