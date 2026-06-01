import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet.dart';
import '../providers/expense_provider.dart';
import '../providers/wallet_provider.dart';

/// A modal sheet for moving money between two of the user's wallets. Creates a
/// real two-legged transfer in [ExpenseProvider].
class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const TransferSheet(),
    );
  }

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromId;
  String? _toId;
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final wallets = context.read<WalletProvider>().wallets;
    _fromId = wallets.isNotEmpty ? wallets.first.id : null;
    _toId = wallets.length > 1 ? wallets[1].id : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromId == null || _toId == null || _fromId == _toId) return;

    final amount = double.parse(_amountController.text.replaceAll('.', '').trim());
    await context.read<ExpenseProvider>().addTransfer(
          fromWalletId: _fromId!,
          toWalletId: _toId!,
          amount: amount,
          date: _date,
          note: _noteController.text,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sameWallet = _fromId != null && _fromId == _toId;

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
              Text('Transfer between wallets',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _WalletDropdown(
                label: 'From',
                wallets: wallets,
                value: _fromId,
                onChanged: (v) => setState(() => _fromId = v),
              ),
              const SizedBox(height: 14),
              _WalletDropdown(
                label: 'To',
                wallets: wallets,
                value: _toId,
                onChanged: (v) => setState(() => _toId = v),
              ),
              if (sameWallet) ...[
                const SizedBox(height: 8),
                Text('Choose two different wallets.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ],
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
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)', hintText: 'e.g. Top up e-wallet'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: sameWallet ? null : _save,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletDropdown extends StatelessWidget {
  const _WalletDropdown({
    required this.label,
    required this.wallets,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Wallet> wallets;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final w in wallets)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                Icon(w.icon, size: 18, color: w.color),
                const SizedBox(width: 10),
                Text(w.name),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
