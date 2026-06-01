import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../models/wallet.dart';
import '../providers/expense_provider.dart';
import '../providers/wallet_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'transfer_sheet.dart';

/// Wallets tab: shows each wallet's balance (derived from its transactions,
/// converted to the base currency for the total), and supports add/edit/delete
/// plus transfers between wallets.
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final expenses = context.watch<ExpenseProvider>();

    if (!walletProvider.isLoaded || !expenses.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final wallets = walletProvider.wallets;
    final totalInBase = wallets.fold<double>(
      0,
      (sum, w) => sum + walletProvider.toBase(expenses.balanceForWallet(w.id), w),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        Container(
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
              Text('Total net worth',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              Text(
                Formatters.currency(totalInBase),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Across ${wallets.length} wallet${wallets.length == 1 ? '' : 's'} · base ${walletProvider.baseCurrencyCode}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (wallets.length > 1)
          OutlinedButton.icon(
            onPressed: () => TransferSheet.show(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer between wallets'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your wallets',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => _editWallet(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final wallet in wallets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WalletCard(
              wallet: wallet,
              balance: expenses.balanceForWallet(wallet.id),
              onEdit: () => _editWallet(context, wallet),
              onDelete: wallets.length > 1
                  ? () => _deleteWallet(context, wallet)
                  : null,
            ),
          ),
      ],
    );
  }

  Future<void> _editWallet(BuildContext context, Wallet? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _WalletEditor(existing: existing),
    );
  }

  Future<void> _deleteWallet(BuildContext context, Wallet wallet) async {
    final walletProvider = context.read<WalletProvider>();
    final expenses = context.read<ExpenseProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final others = walletProvider.wallets.where((w) => w.id != wallet.id).toList();
    final target = others.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${wallet.name}"?'),
        content: Text(
          'Transactions in this wallet will be moved to "${target.name}". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;
    await expenses.reassignWallet(wallet.id, target.id);
    await walletProvider.removeWallet(wallet.id);
    messenger.showSnackBar(
      SnackBar(content: Text('Moved transactions to "${target.name}".')),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.balance,
    required this.onEdit,
    required this.onDelete,
  });

  final Wallet wallet;
  final double balance;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final currency = Currency.byCode(wallet.currencyCode);
    return Container(
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
              color: wallet.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(wallet.icon, color: wallet.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${currency.code} · ${Formatters.currencyIn(balance, currency)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet editor for creating or editing a wallet.
class _WalletEditor extends StatefulWidget {
  const _WalletEditor({this.existing});
  final Wallet? existing;

  @override
  State<_WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends State<_WalletEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _rateController;

  late String _currencyCode;
  late int _colorValue;
  late int _iconCodePoint;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final base = context.read<WalletProvider>().baseCurrencyCode;
    _nameController = TextEditingController(text: e?.name ?? '');
    _rateController =
        TextEditingController(text: (e?.rateToBase ?? 1).toString());
    _currencyCode = e?.currencyCode ?? base;
    _colorValue = e?.colorValue ?? Wallet.colorChoices.first;
    _iconCodePoint = e?.iconCodePoint ?? Wallet.iconChoices.first.codePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<WalletProvider>();
    final rate = double.tryParse(_rateController.text.trim()) ?? 1.0;

    if (_isEditing) {
      await provider.updateWallet(widget.existing!.copyWith(
        name: _nameController.text,
        currencyCode: _currencyCode,
        colorValue: _colorValue,
        iconCodePoint: _iconCodePoint,
        rateToBase: rate,
      ));
    } else {
      await provider.addWallet(
        name: _nameController.text,
        currencyCode: _currencyCode,
        colorValue: _colorValue,
        iconCodePoint: _iconCodePoint,
        rateToBase: rate,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final base = context.read<WalletProvider>().baseCurrencyCode;
    final isBase = _currencyCode == base;
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
              Text(_isEditing ? 'Edit wallet' : 'New wallet',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'e.g. Cash, Bank, E-wallet'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: [
                  for (final c in Currency.all)
                    DropdownMenuItem(
                        value: c.code, child: Text('${c.code} — ${c.name}')),
                ],
                onChanged: (v) =>
                    setState(() => _currencyCode = v ?? _currencyCode),
              ),
              if (!isBase) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Rate to $base',
                    helperText: '1 $_currencyCode = ? $base',
                  ),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').trim());
                    if (value == null || value <= 0) return 'Enter a valid rate';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 18),
              Text('Icon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icon in Wallet.iconChoices)
                    _PickChip(
                      selected: icon.codePoint == _iconCodePoint,
                      onTap: () =>
                          setState(() => _iconCodePoint = icon.codePoint),
                      child: Icon(icon, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Color', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final value in Wallet.colorChoices)
                    GestureDetector(
                      onTap: () => setState(() => _colorValue = value),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorValue == value
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEditing ? 'Update wallet' : 'Create wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
