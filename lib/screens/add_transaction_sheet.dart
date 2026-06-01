import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/expense_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatters.dart';

/// A modal bottom sheet for creating *or editing* a transaction.
///
/// Presented with [show]. When [existing] is provided the form is pre-filled
/// and saving updates that transaction in place; otherwise a new one is added.
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, this.existing});

  /// The transaction being edited, or `null` when adding a new one.
  final Transaction? existing;

  /// Opens the sheet as a rounded, draggable modal that respects the keyboard.
  /// Pass [existing] to open in edit mode.
  static Future<void> show(BuildContext context, {Transaction? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AddTransactionSheet(existing: existing),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  late TransactionType _type;
  late String _categoryId;
  late DateTime _date;
  String? _walletId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    _type = existing?.type ?? TransactionType.expense;
    _categoryId = existing?.categoryId ?? 'food';
    _date = existing?.date ?? DateTime.now();
    _walletId = existing?.walletId ??
        context.read<WalletProvider>().defaultWallet?.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll('.', '').trim());
    final provider = context.read<ExpenseProvider>();

    if (_isEditing) {
      await provider.updateTransaction(
        id: widget.existing!.id,
        title: _titleController.text,
        amount: amount,
        date: _date,
        type: _type,
        categoryId: _categoryId,
        walletId: _walletId,
      );
    } else {
      await provider.addTransaction(
        title: _titleController.text,
        amount: amount,
        date: _date,
        type: _type,
        categoryId: _categoryId,
        walletId: _walletId,
      );
    }

    if (mounted) Navigator.of(context).pop();
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
              Text(
                _isEditing ? 'Edit transaction' : 'New transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              // Income / Expense toggle.
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Lunch, Salary, Taxi',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                  final value = double.tryParse(v.replaceAll('.', '').trim());
                  if (value == null || value <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              Text('Category', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in Category.selectable)
                    _CategoryChip(
                      category: c,
                      selected: c.id == _categoryId,
                      onTap: () => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Wallet selector — only shown when more than one wallet exists.
              Builder(builder: (context) {
                final wallets = context.watch<WalletProvider>().wallets;
                if (wallets.length < 2) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in wallets)
                          ChoiceChip(
                            label: Text(w.name),
                            avatar: Icon(w.icon, size: 16, color: w.color),
                            selected: _walletId == w.id,
                            onSelected: (_) =>
                                setState(() => _walletId = w.id),
                          ),
                      ],
                    ),
                  ],
                );
              }),
              const SizedBox(height: 18),

              // Date row.
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(Formatters.dayLabel(_date),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEditing ? 'Update transaction' : 'Save transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.18)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? category.color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 18, color: category.color),
            const SizedBox(width: 8),
            Text(
              category.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
