import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/insights_section.dart';
import '../widgets/month_selector.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/spending_chart.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_sheet.dart';

/// The main tab: balance hero card, month picker, spending chart, real-data
/// insights, and the searchable/filterable transaction list. Tapping a row
/// opens the edit sheet; swiping deletes with undo.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final transactions = provider.filteredTransactions;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BalanceCard(
                  balance: provider.balanceForMonth,
                  income: provider.incomeForMonth,
                  expense: provider.expenseForMonth,
                ),
                const SizedBox(height: 20),
                MonthSelector(
                  months: provider.availableMonths,
                  selected: provider.selectedMonth,
                  onSelected: provider.selectMonth,
                ),
                const SizedBox(height: 20),
                if (provider.insights.isNotEmpty) ...[
                  InsightsSection(insights: provider.insights),
                  const SizedBox(height: 20),
                ],
                _SectionCard(
                  title: 'Spending breakdown',
                  child: SpendingChart(data: provider.expenseByCategory),
                ),
                const SizedBox(height: 20),
                const SearchFilterBar(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Transactions',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      provider.hasActiveFilters
                          ? '${transactions.length} match'
                          : '${transactions.length} this month',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (transactions.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyState(
              hasFilters: provider.hasActiveFilters,
              onClear: provider.clearFilters,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return Dismissible(
                  key: ValueKey(tx.id),
                  direction: DismissDirection.endToStart,
                  background: _deleteBackground(context),
                  onDismissed: (_) {
                    provider.deleteTransaction(tx.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Deleted "${tx.title}"'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => provider.restoreTransaction(tx),
                          ),
                        ),
                      );
                  },
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => AddTransactionSheet.show(context, existing: tx),
                    child: TransactionTile(transaction: tx),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _deleteBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No transactions match your filters'
                  : 'No transactions this month',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters.'
                  : 'Tap the “+” button to add your first one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
