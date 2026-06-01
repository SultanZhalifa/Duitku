import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Settings tab: data backup/restore and CSV export, security (app lock),
/// reminders, base currency, and danger-zone data clearing. Every toggle drives
/// real behaviour, with native-only features hidden on unsupported platforms.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _exportService = const ExportService();
  final _backupService = const BackupService();
  bool _busy = false;

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _exportCsv() async {
    final expenses = context.read<ExpenseProvider>();
    if (expenses.isEmpty) {
      _messenger.showSnackBar(
          const SnackBar(content: Text('There is no data to export yet.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _exportService.shareCsv(expenses.exportCsv());
    } on ExportException catch (e) {
      _messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      await _backupService.exportBackup(
        expenses: context.read<ExpenseProvider>(),
        wallets: context.read<WalletProvider>(),
        budgets: context.read<BudgetProvider>(),
        recurring: context.read<RecurringProvider>(),
      );
    } on BackupException catch (e) {
      _messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    // Capture providers before any async gap so we don't use context after.
    final expenses = context.read<ExpenseProvider>();
    final wallets = context.read<WalletProvider>();
    final budgets = context.read<BudgetProvider>();
    final recurring = context.read<RecurringProvider>();

    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the contents of a Duitku backup file. This replaces ALL '
              'current data.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: '{ "app": "Duitku", ... }',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Restore')),
        ],
      ),
    );

    if (json == null || json.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await _backupService.restoreFromJson(
        json: json,
        expenses: expenses,
        wallets: wallets,
        budgets: budgets,
        recurring: recurring,
      );
      if (mounted) {
        _messenger.showSnackBar(
            const SnackBar(content: Text('Backup restored successfully.')));
      }
    } on BackupException catch (e) {
      _messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final settings = context.read<SettingsProvider>();
    if (!value) {
      await settings.setAppLockEnabled(false);
      return;
    }
    // Require a successful authentication before enabling the lock.
    final ok = await AuthService.instance.authenticate(
        reason: 'Confirm to enable app lock');
    if (ok) {
      await settings.setAppLockEnabled(true);
    } else if (mounted) {
      _messenger.showSnackBar(
          const SnackBar(content: Text('Authentication failed; lock not enabled.')));
    }
  }

  Future<void> _toggleReminders(bool value) async {
    final settings = context.read<SettingsProvider>();
    if (!value) {
      await settings.setRemindersEnabled(false);
      await NotificationService.instance.cancelAll();
      return;
    }
    final granted = await NotificationService.instance.requestPermission();
    if (granted) {
      await settings.setRemindersEnabled(true);
    } else if (mounted) {
      _messenger.showSnackBar(const SnackBar(
          content: Text('Notification permission denied.')));
    }
  }

  Future<void> _pickBaseCurrency() async {
    final wallets = context.read<WalletProvider>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        children: [
          for (final c in Currency.all)
            ListTile(
              title: Text('${c.code} — ${c.name}'),
              trailing: c.code == wallets.baseCurrencyCode
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, c.code),
            ),
        ],
      ),
    );
    if (selected != null) await wallets.setBaseCurrency(selected);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every transaction, budget, and recurring '
          'rule on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final expenses = context.read<ExpenseProvider>();
    final budgets = context.read<BudgetProvider>();
    final recurring = context.read<RecurringProvider>();
    await expenses.replaceAll([]);
    await budgets.clearAll();
    await recurring.replaceAll([]);
    if (mounted) {
      _messenger.showSnackBar(const SnackBar(content: Text('All data cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final wallets = context.watch<WalletProvider>();
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;
    // Biometric lock is a native capability; hidden on web.
    final lockSupported = !kIsWeb;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        _sectionLabel(context, 'Data'),
        _SettingsTile(
          icon: Icons.backup_outlined,
          iconColor: AppTheme.seed,
          title: 'Back up all data',
          subtitle: 'Save a full JSON backup you can restore later',
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _exportBackup,
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.restore,
          iconColor: AppTheme.income,
          title: 'Restore from backup',
          subtitle: 'Import a Duitku backup file (replaces current data)',
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _importBackup,
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.ios_share,
          iconColor: AppTheme.warn,
          title: 'Export to CSV',
          subtitle: 'Share all ${expenses.all.length} transactions as a spreadsheet',
          trailing: _busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _busy ? null : _exportCsv,
        ),

        const SizedBox(height: 24),
        _sectionLabel(context, 'Preferences'),
        _SettingsSwitchTile(
          icon: Icons.lock_outline,
          iconColor: AppTheme.seed,
          title: 'App lock',
          subtitle: lockSupported
              ? 'Require biometrics or device passcode to open'
              : 'Not available on this platform',
          value: settings.appLockEnabled,
          onChanged: lockSupported ? _toggleAppLock : null,
        ),
        const SizedBox(height: 12),
        _SettingsSwitchTile(
          icon: Icons.notifications_outlined,
          iconColor: AppTheme.warn,
          title: 'Recurring reminders',
          subtitle: NotificationService.instance.isSupported
              ? 'Get notified about upcoming recurring transactions'
              : 'Not available on this platform',
          value: settings.remindersEnabled,
          onChanged:
              NotificationService.instance.isSupported ? _toggleReminders : null,
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.currency_exchange,
          iconColor: AppTheme.income,
          title: 'Base currency',
          subtitle: 'Totals are shown in ${wallets.baseCurrencyCode}',
          trailing: Text(wallets.baseCurrencyCode,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: _pickBaseCurrency,
        ),

        const SizedBox(height: 24),
        _sectionLabel(context, 'Danger zone'),
        _SettingsTile(
          icon: Icons.delete_outline,
          iconColor: AppTheme.expense,
          title: 'Clear all data',
          subtitle: 'Remove every transaction, budget and rule',
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _confirmClear,
        ),

        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppTheme.heroGradient),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text('Duitku',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 2),
              Text('Offline-first expense tracker • v1.0.0',
                  style: TextStyle(color: scheme.outline, fontSize: 12)),
              const SizedBox(height: 4),
              Text('All data is stored only on this device.',
                  style: TextStyle(color: scheme.outline, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(child: _Labels(title: title, subtitle: subtitle)),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(child: _Labels(title: title, subtitle: subtitle)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _Labels extends StatelessWidget {
  const _Labels({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontSize: 12.5)),
      ],
    );
  }
}
