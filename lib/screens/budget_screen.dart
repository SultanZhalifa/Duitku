import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Budget tab: set a monthly limit per category and track real spending against
/// it. Progress and over-budget warnings are computed from actual transactions
/// for the selected month — nothing is fabricated.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>();
    final expenses = context.watch<ExpenseProvider>();

    if (!budgets.isLoaded || !expenses.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final spentTotal = Category.all
        .where((c) => budgets.limitFor(c.id) != null)
        .fold<double>(0, (sum, c) => sum + expenses.expenseForCategory(c.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        if (!budgets.isEmpty)
          _OverallCard(
            spent: spentTotal,
            limit: budgets.totalBudget,
          ),
        if (!budgets.isEmpty) const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Monthly budgets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          'Tap a category to set or change its monthly limit. Spending is tracked against ${Formatters.monthYear(expenses.selectedMonth)}.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        for (final category in Category.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BudgetRow(
              category: category,
              limit: budgets.limitFor(category.id),
              spent: expenses.expenseForCategory(category.id),
              onEdit: () => _editBudget(context, category, budgets),
            ),
          ),
      ],
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    Category category,
    BudgetProvider budgets,
  ) async {
    final controller = TextEditingController(
      text: budgets.limitFor(category.id)?.toStringAsFixed(0) ?? '',
    );

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${category.label} budget'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: 'Rp ',
            ),
          ),
          actions: [
            if (budgets.limitFor(category.id) != null)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _BudgetDialogResult.remove()),
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                Navigator.pop(context, _BudgetDialogResult.save(value));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await budgets.setBudget(category.id, result.remove ? null : result.value);
  }
}

/// Result of the budget editing dialog: either save a value or remove the limit.
class _BudgetDialogResult {
  const _BudgetDialogResult.save(this.value) : remove = false;
  const _BudgetDialogResult.remove()
      : value = null,
        remove = true;

  final double? value;
  final bool remove;
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.spent, required this.limit});

  final double spent;
  final double limit;

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;
    final remaining = limit - spent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.heroGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            over ? 'Over budget' : 'Remaining this month',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.currency(remaining.abs()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(
                over ? const Color(0xFF7A1F12) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${Formatters.currency(spent)} of ${Formatters.currency(limit)} used',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.category,
    required this.limit,
    required this.spent,
    required this.onEdit,
  });

  final Category category;
  final double? limit;
  final double spent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLimit = limit != null;
    final ratio = (limit == null || limit == 0)
        ? 0.0
        : (spent / limit!).clamp(0.0, 1.0);
    final over = hasLimit && spent > limit!;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: over ? Border.all(color: AppTheme.warn, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        hasLimit
                            ? '${Formatters.currency(spent)} of ${Formatters.currency(limit!)}'
                            : 'No budget set',
                        style: TextStyle(
                          color: over ? AppTheme.warn : scheme.outline,
                          fontSize: 12.5,
                          fontWeight:
                              over ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasLimit ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 20,
                  color: scheme.outline,
                ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: category.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(
                    over ? AppTheme.warn : category.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
