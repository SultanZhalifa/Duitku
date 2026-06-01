import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';

/// Search field plus a row of filter chips (type + category) wired directly to
/// [ExpenseProvider]. Filtering is applied to the visible list only; monthly
/// totals and charts continue to reflect the full month.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({super.key});

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: context.read<ExpenseProvider>().searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: provider.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search transactions',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: provider.searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      provider.setSearchQuery('');
                    },
                  ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Expense',
                selected: provider.typeFilter == TransactionType.expense,
                onSelected: (s) => provider
                    .setTypeFilter(s ? TransactionType.expense : null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Income',
                selected: provider.typeFilter == TransactionType.income,
                onSelected: (s) =>
                    provider.setTypeFilter(s ? TransactionType.income : null),
              ),
              const SizedBox(width: 8),
              const _VerticalDivider(),
              const SizedBox(width: 8),
              for (final c in Category.all) ...[
                _FilterChip(
                  label: c.label,
                  color: c.color,
                  selected: provider.categoryFilter == c.id,
                  onSelected: (s) =>
                      provider.setCategoryFilter(s ? c.id : null),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? tint : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: tint.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? tint : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 20,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
