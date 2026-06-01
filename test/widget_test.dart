import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/recurring_rule.dart';
import 'package:flutter_application_1/models/transaction.dart';
import 'package:flutter_application_1/providers/budget_provider.dart';
import 'package:flutter_application_1/providers/expense_provider.dart';
import 'package:flutter_application_1/providers/recurring_provider.dart';
import 'package:flutter_application_1/providers/settings_provider.dart';
import 'package:flutter_application_1/providers/wallet_provider.dart';
import 'package:flutter_application_1/screens/home_shell.dart';
import 'package:flutter_application_1/screens/onboarding_screen.dart';
import 'package:flutter_application_1/services/backup_service.dart';

/// Builds a fully-provided HomeShell for widget tests, with all providers
/// backed by in-memory SharedPreferences. This is standard test infrastructure
/// — the production app always uses real on-device storage and real data.
Future<Widget> _bootShell({bool onboarded = true}) async {
  final prefs = await SharedPreferences.getInstance();
  final expenses = ExpenseProvider(prefs: prefs);
  final wallets = WalletProvider(prefs: prefs);
  final budgets = BudgetProvider(prefs: prefs);
  final recurring = RecurringProvider(prefs: prefs);
  final settings = SettingsProvider(prefs: prefs);
  await wallets.load();
  await expenses.load();
  expenses.defaultWalletId = wallets.defaultWallet?.id;
  await budgets.load();
  await recurring.load();
  await settings.load();
  if (onboarded) await settings.completeOnboarding();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ExpenseProvider>.value(value: expenses),
      ChangeNotifierProvider<WalletProvider>.value(value: wallets),
      ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
      ChangeNotifierProvider<RecurringProvider>.value(value: recurring),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: const MaterialApp(home: HomeShell()),
  );
}

void main() {
  group('ExpenseProvider', () {
    late ExpenseProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider =
          ExpenseProvider(prefs: await SharedPreferences.getInstance());
      await provider.load();
    });

    test('starts completely empty (no seeded/demo data)', () {
      expect(provider.all, isEmpty);
      expect(provider.isEmpty, isTrue);
      expect(provider.incomeForMonth, 0);
      expect(provider.expenseForMonth, 0);
      expect(provider.insights, isEmpty);
    });

    test('balance equals income minus expense for the month', () async {
      await provider.addTransaction(
        title: 'Salary',
        amount: 5000000,
        date: DateTime.now(),
        type: TransactionType.income,
        categoryId: 'salary',
      );
      await provider.addTransaction(
        title: 'Groceries',
        amount: 200000,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'food',
      );
      expect(provider.balanceForMonth, 4800000);
    });

    test('editing a transaction updates totals in place', () async {
      await provider.addTransaction(
        title: 'Lunch',
        amount: 50000,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'food',
      );
      final tx = provider.all.single;
      await provider.updateTransaction(
        id: tx.id,
        title: 'Lunch (corrected)',
        amount: 75000,
        date: tx.date,
        type: TransactionType.expense,
        categoryId: 'food',
      );
      expect(provider.all.single.title, 'Lunch (corrected)');
      expect(provider.expenseForMonth, 75000);
    });

    test('CSV export contains a header and a row per transaction', () async {
      await provider.addTransaction(
        title: 'Books',
        amount: 120000,
        date: DateTime(2026, 1, 15),
        type: TransactionType.expense,
        categoryId: 'shopping',
      );
      final lines = provider.exportCsv().trim().split('\n');
      expect(lines.first, 'Date,Type,Category,Title,Amount');
      expect(lines.length, 2);
      expect(lines[1], contains('Books'));
    });
  });

  group('Transfers and wallets', () {
    late ExpenseProvider expenses;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      expenses = ExpenseProvider(prefs: await SharedPreferences.getInstance());
      await expenses.load();
    });

    test('a transfer creates two linked legs and nets to zero spending',
        () async {
      await expenses.addTransfer(
        fromWalletId: 'cash',
        toWalletId: 'bank',
        amount: 100000,
        date: DateTime.now(),
      );
      // Two legs created.
      expect(expenses.all.length, 2);
      expect(expenses.all.every((t) => t.isTransfer), isTrue);
      // Transfers don't count as income or expense.
      expect(expenses.expenseForMonth, 0);
      expect(expenses.incomeForMonth, 0);
      // Wallet balances reflect the move.
      expect(expenses.balanceForWallet('cash'), -100000);
      expect(expenses.balanceForWallet('bank'), 100000);
    });

    test('deleting one leg of a transfer removes both', () async {
      await expenses.addTransfer(
        fromWalletId: 'cash',
        toWalletId: 'bank',
        amount: 50000,
        date: DateTime.now(),
      );
      await expenses.deleteTransaction(expenses.all.first.id);
      expect(expenses.all, isEmpty);
    });

    test('reassignWallet moves transactions to another wallet', () async {
      await expenses.addTransaction(
        title: 'Snack',
        amount: 10000,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: 'cash',
      );
      await expenses.reassignWallet('cash', 'bank');
      expect(expenses.balanceForWallet('cash'), 0);
      expect(expenses.balanceForWallet('bank'), -10000);
    });
  });

  group('WalletProvider', () {
    late WalletProvider wallets;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      wallets = WalletProvider(prefs: await SharedPreferences.getInstance());
      await wallets.load();
    });

    test('creates a default wallet on first run', () {
      expect(wallets.wallets, hasLength(1));
      expect(wallets.defaultWallet, isNotNull);
    });

    test('cannot remove the last wallet', () async {
      final removed = await wallets.removeWallet(wallets.wallets.first.id);
      expect(removed, isFalse);
      expect(wallets.wallets, hasLength(1));
    });

    test('converts to base currency using the wallet rate', () async {
      final usd = await wallets.addWallet(
        name: 'USD',
        currencyCode: 'USD',
        colorValue: 0xFF000000,
        iconCodePoint: 0xe0e0,
        rateToBase: 16000,
      );
      expect(wallets.toBase(10, usd), 160000);
    });
  });

  group('RecurringProvider', () {
    late ExpenseProvider expenses;
    late RecurringProvider recurring;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expenses = ExpenseProvider(prefs: prefs);
      recurring = RecurringProvider(prefs: prefs);
      await expenses.load();
      await recurring.load();
    });

    test('catchUp generates a transaction for a rule due today', () async {
      await recurring.addRule(
        title: 'Netflix',
        amount: 65000,
        type: TransactionType.expense,
        categoryId: 'entertainment',
        walletId: null,
        frequency: Frequency.monthly,
        startDate: DateTime.now(),
      );
      final created = await recurring.catchUp(expenses);
      expect(created, 1);
      expect(expenses.all.single.title, 'Netflix');
    });

    test('catchUp fills in every missed daily occurrence exactly once',
        () async {
      final start = DateTime.now().subtract(const Duration(days: 3));
      await recurring.addRule(
        title: 'Coffee',
        amount: 20000,
        type: TransactionType.expense,
        categoryId: 'food',
        walletId: null,
        frequency: Frequency.daily,
        startDate: start,
      );
      final created = await recurring.catchUp(expenses);
      expect(created, 4); // days -3, -2, -1, today

      // Running again creates nothing new (nextDue already advanced).
      final again = await recurring.catchUp(expenses);
      expect(again, 0);
    });
  });

  group('BackupService', () {
    test('backup round-trips all data through JSON', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final expenses = ExpenseProvider(prefs: prefs);
      final wallets = WalletProvider(prefs: prefs);
      final budgets = BudgetProvider(prefs: prefs);
      final recurring = RecurringProvider(prefs: prefs);
      await wallets.load();
      await expenses.load();
      await budgets.load();
      await recurring.load();

      await expenses.addTransaction(
        title: 'Rent',
        amount: 2000000,
        date: DateTime(2026, 3, 1),
        type: TransactionType.expense,
        categoryId: 'bills',
      );
      await budgets.setBudget('food', 750000);

      const service = BackupService();
      final json = service.buildBackupJson(
        expenses: expenses,
        wallets: wallets,
        budgets: budgets,
        recurring: recurring,
      );

      expect(json, contains('"app": "Duitku"'));
      expect(json, contains('Rent'));
      expect(json, contains('schemaVersion'));
      expect(json, contains('"food": 750000'));
    });

    test('restoreFromJson rebuilds data into fresh providers', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Source set with one transaction and a budget.
      final srcExpenses = ExpenseProvider(prefs: prefs);
      final srcWallets = WalletProvider(prefs: prefs);
      final srcBudgets = BudgetProvider(prefs: prefs);
      final srcRecurring = RecurringProvider(prefs: prefs);
      await srcWallets.load();
      await srcExpenses.load();
      await srcBudgets.load();
      await srcRecurring.load();
      await srcExpenses.addTransaction(
        title: 'Salary',
        amount: 9000000,
        date: DateTime(2026, 4, 1),
        type: TransactionType.income,
        categoryId: 'salary',
      );
      await srcBudgets.setBudget('transport', 300000);

      const service = BackupService();
      final json = service.buildBackupJson(
        expenses: srcExpenses,
        wallets: srcWallets,
        budgets: srcBudgets,
        recurring: srcRecurring,
      );

      // Restore into a completely fresh, empty set of providers.
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final dstExpenses = ExpenseProvider(prefs: freshPrefs);
      final dstWallets = WalletProvider(prefs: freshPrefs);
      final dstBudgets = BudgetProvider(prefs: freshPrefs);
      final dstRecurring = RecurringProvider(prefs: freshPrefs);
      await dstWallets.load();
      await dstExpenses.load();
      await dstBudgets.load();
      await dstRecurring.load();

      await service.restoreFromJson(
        json: json,
        expenses: dstExpenses,
        wallets: dstWallets,
        budgets: dstBudgets,
        recurring: dstRecurring,
      );

      expect(dstExpenses.all.single.title, 'Salary');
      expect(dstBudgets.limitFor('transport'), 300000);
    });

    test('rejects a non-Duitku JSON document', () async {
      const service = BackupService();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final expenses = ExpenseProvider(prefs: prefs);
      final wallets = WalletProvider(prefs: prefs);
      final budgets = BudgetProvider(prefs: prefs);
      final recurring = RecurringProvider(prefs: prefs);
      await wallets.load();
      await expenses.load();
      await budgets.load();
      await recurring.load();

      expect(
        () => service.restoreFromJson(
          json: '{"hello":"world"}',
          expenses: expenses,
          wallets: wallets,
          budgets: budgets,
          recurring: recurring,
        ),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('Onboarding and boot', () {
    testWidgets('first run shows onboarding', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const DuitkuApp());
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Welcome to Duitku'), findsOneWidget);
    });

    testWidgets('home shell renders the overview after onboarding',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await _bootShell());
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Balance this month'), findsOneWidget);
    });
  });
}
