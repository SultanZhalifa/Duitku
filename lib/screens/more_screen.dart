import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

/// The "More" tab: a hub linking to features that don't warrant their own
/// bottom-bar slot (recurring rules and settings).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        _MoreTile(
          icon: Icons.event_repeat,
          color: AppTheme.seed,
          title: 'Recurring transactions',
          subtitle: 'Automate salary, bills and subscriptions',
          onTap: () => _open(context, 'Recurring', const RecurringScreen()),
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.settings,
          color: AppTheme.income,
          title: 'Settings',
          subtitle: 'Backup, security, currency and more',
          onTap: () => _open(context, 'Settings', const SettingsScreen()),
        ),
      ],
    );
  }

  void _open(BuildContext context, String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: child),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
