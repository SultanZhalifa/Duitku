import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/budget_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/home_shell.dart';
import 'screens/lock_gate.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DuitkuApp());
}

/// Root of the app. Provides all state, then defers to [_AppBootstrap] which
/// loads data, runs recurring catch-up, and chooses what to show first
/// (onboarding, lock gate, or the home shell).
class DuitkuApp extends StatelessWidget {
  const DuitkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Duitku',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _AppBootstrap(),
      ),
    );
  }
}

/// Orchestrates startup: loads every provider in the right order, materialises
/// any due recurring transactions, then routes to onboarding / lock / home.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _ready = false;
  bool _unlocked = false;
  int _generatedCount = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final expenses = context.read<ExpenseProvider>();
    final wallets = context.read<WalletProvider>();
    final budgets = context.read<BudgetProvider>();
    final recurring = context.read<RecurringProvider>();
    final settings = context.read<SettingsProvider>();

    // Wallets first so transactions can be attributed to the default wallet.
    await wallets.load();
    await expenses.load();
    expenses.defaultWalletId = wallets.defaultWallet?.id;
    await budgets.load();
    await recurring.load();
    await settings.load();

    // Generate any recurring transactions that came due while away.
    _generatedCount = await recurring.catchUp(expenses);

    // Pre-warm notifications on supported platforms.
    if (settings.remindersEnabled) {
      await NotificationService.instance.init();
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settings = context.watch<SettingsProvider>();

    // First run → onboarding.
    if (!settings.onboarded) {
      return OnboardingScreen(
        onDone: () => settings.completeOnboarding(),
      );
    }

    // App lock enabled and not yet unlocked this session → lock gate.
    if (settings.appLockEnabled && !_unlocked) {
      return LockGate(onUnlocked: () => setState(() => _unlocked = true));
    }

    return _HomeWithGeneratedNotice(generated: _generatedCount);
  }
}

/// Shows the home shell and, once, a snackbar noting how many recurring
/// transactions were auto-generated at startup.
class _HomeWithGeneratedNotice extends StatefulWidget {
  const _HomeWithGeneratedNotice({required this.generated});
  final int generated;

  @override
  State<_HomeWithGeneratedNotice> createState() =>
      _HomeWithGeneratedNoticeState();
}

class _HomeWithGeneratedNoticeState extends State<_HomeWithGeneratedNotice> {
  @override
  void initState() {
    super.initState();
    if (widget.generated > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final n = widget.generated;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added $n recurring transaction${n == 1 ? '' : 's'} that came due.'),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => const HomeShell();
}
