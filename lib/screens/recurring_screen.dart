import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import '../providers/recurring_provider.dart';
import '../providers/wallet_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Recurring tab: manage rules that automatically generate real transactions on
/// a schedule. Toggling a rule off pauses generation; deleting removes it.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecurringProvider>();
    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final rules = provider.rules;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRule(context),
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
      body: rules.isEmpty
          ? const _RecurringEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              children: [
                Text(
                  'Recurring transactions are generated automatically when they '
                  'come due — each one is a normal transaction you can edit or '
                  'delete.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RuleCard(rule: rule),
                  ),
              ],
            ),
    );
  }

  Future<void> _addRule(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _RuleEditor(),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});
  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RecurringProvider>();
    final category = Category.byId(rule.categoryId);
    final isExpense = rule.type == TransactionType.expense;

    return Dismissible(
      key: ValueKey(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => provider.deleteRule(rule.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${rule.frequency.label} · next ${Formatters.dayLabel(rule.nextDue)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${Formatters.currency(rule.amount)}',
                  style: TextStyle(
                    color: isExpense ? AppTheme.expense : AppTheme.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: rule.active,
                    onChanged: (v) => provider.toggleActive(rule.id, v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor();

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _categoryId = 'bills';
  Frequency _frequency = Frequency.monthly;
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.replaceAll('.', '').trim());
    final walletId = context.read<WalletProvider>().defaultWallet?.id;

    await context.read<RecurringProvider>().addRule(
          title: _titleController.text,
          amount: amount,
          type: _type,
          categoryId: _categoryId,
          walletId: walletId,
          frequency: _frequency,
          startDate: _startDate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('New recurring rule',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                      value: TransactionType.expense, label: Text('Expense')),
                  ButtonSegment(
                      value: TransactionType.income, label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Title', hintText: 'e.g. Salary, Netflix'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: 'Rp '),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter an amount';
                  final value = double.tryParse(v.replaceAll('.', '').trim());
                  if (value == null || value <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [
                  for (final f in Frequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in Category.selectable)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 18, color: c.color),
                          const SizedBox(width: 10),
                          Text(c.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickStart,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Starts / next due'),
                  child: Text(Formatters.dayLabel(_startDate)),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Create rule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringEmptyState extends StatelessWidget {
  const _RecurringEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_repeat_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('No recurring rules yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Automate salary, subscriptions, or bills with a rule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
