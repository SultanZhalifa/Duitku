import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/insight.dart';
import '../models/transaction.dart';

/// Owns the list of [Transaction]s and exposes derived totals for the UI.
///
/// All data is persisted locally with `shared_preferences` as a single JSON
/// blob, so the app is fully offline and survives restarts. The provider is the
/// single source of truth — widgets read from it and never mutate the list
/// directly. There is no seeded/demo data: every value shown in the app is
/// computed from transactions the user entered.
class ExpenseProvider extends ChangeNotifier {
  /// [prefs] can be injected in tests; in production it's lazily resolved.
  // ignore: prefer_initializing_formals
  ExpenseProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'transactions';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;
  final List<Transaction> _transactions = [];

  /// The month currently being viewed. Defaults to the current month.
  DateTime _selectedMonth = _firstOfMonth(DateTime.now());

  /// Active filters on the Home transaction list.
  String _searchQuery = '';
  String? _categoryFilter; // null = all categories
  TransactionType? _typeFilter; // null = both income & expense

  bool _loaded = false;
  bool get isLoaded => _loaded;

  DateTime get selectedMonth => _selectedMonth;
  String get searchQuery => _searchQuery;
  String? get categoryFilter => _categoryFilter;
  TransactionType? get typeFilter => _typeFilter;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _categoryFilter != null || _typeFilter != null;

  /// Loads persisted data. On first run the list is simply empty — the app
  /// opens to a friendly empty state rather than fabricated data.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);

    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _transactions
        ..clear()
        ..addAll(decoded.map((e) => Transaction.fromJson(e as Map<String, dynamic>)));
    }

    _loaded = true;
    notifyListeners();
  }

  // ---- Reads -------------------------------------------------------------

  /// All transactions, newest first.
  List<Transaction> get all {
    final sorted = [..._transactions]..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(sorted);
  }

  bool get isEmpty => _transactions.isEmpty;

  /// Transactions that fall within [selectedMonth], newest first.
  List<Transaction> get transactionsForSelectedMonth {
    return all.where((t) => _isInSelectedMonth(t.date)).toList();
  }

  /// The selected month's transactions after applying search + filters.
  /// Drives the Home list; totals/charts use the unfiltered month data.
  List<Transaction> get filteredTransactions {
    final query = _searchQuery.trim().toLowerCase();
    return transactionsForSelectedMonth.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (_categoryFilter != null && t.categoryId != _categoryFilter) {
        return false;
      }
      if (query.isNotEmpty &&
          !t.title.toLowerCase().contains(query) &&
          !t.category.label.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  double get incomeForMonth => _incomeFor(_selectedMonth);
  double get expenseForMonth => _expenseFor(_selectedMonth);
  double get balanceForMonth => incomeForMonth - expenseForMonth;

  /// Total expense per category for the selected month, sorted high → low.
  /// Used to draw the pie chart and its legend.
  List<MapEntry<Category, double>> get expenseByCategory {
    final totals = <String, double>{};
    for (final t in transactionsForSelectedMonth
        .where((t) => t.isExpense && !t.isTransfer)) {
      totals.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final entries = totals.entries
        .map((e) => MapEntry(Category.byId(e.key), e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Expense total spent so far in [categoryId] during the selected month.
  /// Used by the budget screen to compute progress.
  double expenseForCategory(String categoryId) {
    return transactionsForSelectedMonth
        .where((t) => t.isExpense && !t.isTransfer && t.categoryId == categoryId)
        .fold(0, (sum, t) => sum + t.amount);
  }

  /// Distinct months that contain at least one transaction, newest first,
  /// always including the current month so the picker is never empty.
  List<DateTime> get availableMonths {
    final months = <DateTime>{_firstOfMonth(DateTime.now())};
    for (final t in _transactions) {
      months.add(_firstOfMonth(t.date));
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Expense totals for the last [count] months ending with the selected
  /// month, oldest → newest. Powers the trend line chart on the Stats screen.
  List<MapEntry<DateTime, double>> monthlyExpenseTrend({int count = 6}) {
    final result = <MapEntry<DateTime, double>>[];
    for (var i = count - 1; i >= 0; i--) {
      final month =
          DateTime(_selectedMonth.year, _selectedMonth.month - i);
      result.add(MapEntry(month, _expenseFor(month)));
    }
    return result;
  }

  /// Insights derived entirely from real data for the selected month.
  /// Returns an empty list when there isn't enough data to say anything true.
  List<Insight> get insights {
    final monthTx = transactionsForSelectedMonth;
    final expenses = monthTx.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) return const [];

    final result = <Insight>[];

    // 1. Top spending category.
    final byCategory = expenseByCategory;
    if (byCategory.isNotEmpty) {
      final top = byCategory.first;
      final share = expenseForMonth == 0 ? 0 : top.value / expenseForMonth;
      result.add(Insight(
        icon: top.key.icon,
        color: top.key.color,
        title: 'Top spending: ${top.key.label}',
        detail:
            '${(share * 100).toStringAsFixed(0)}% of this month\'s expenses.',
      ));
    }

    // 2. Comparison with the previous month (only if it had any spending).
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevExpense = _expenseFor(prevMonth);
    if (prevExpense > 0) {
      final diff = expenseForMonth - prevExpense;
      final pct = (diff / prevExpense * 100).abs();
      final up = diff > 0;
      result.add(Insight(
        icon: up ? Icons.trending_up : Icons.trending_down,
        color: up ? const Color(0xFFC65339) : const Color(0xFF6E8B3D),
        title: up
            ? 'Spending up ${pct.toStringAsFixed(0)}%'
            : 'Spending down ${pct.toStringAsFixed(0)}%',
        detail: 'Compared with last month.',
      ));
    }

    // 3. Average daily spend across days elapsed in the month.
    final now = DateTime.now();
    final isCurrentMonth = _isInSelectedMonth(now);
    final daysElapsed = isCurrentMonth
        ? now.day
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    if (daysElapsed > 0) {
      final avg = expenseForMonth / daysElapsed;
      result.add(Insight(
        icon: Icons.calendar_today,
        color: const Color(0xFFC2693E),
        title: 'Avg ${_formatShort(avg)} / day',
        detail: 'Across $daysElapsed day${daysElapsed == 1 ? '' : 's'}.',
      ));
    }

    return result;
  }

  // ---- Writes ------------------------------------------------------------

  Future<void> addTransaction({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String categoryId,
    String? walletId,
  }) async {
    _transactions.add(Transaction(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount.abs(),
      date: date,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
    ));
    await _persist();
    notifyListeners();
  }

  /// Adds an already-built transaction (used by recurring generation and
  /// backup restore so they keep their original id/links).
  Future<void> addRaw(Transaction transaction) async {
    _transactions.add(transaction);
    await _persist();
    notifyListeners();
  }

  /// Records a wallet-to-wallet transfer as two linked legs: an expense in
  /// [fromWalletId] and an income in [toWalletId], sharing a transfer id.
  Future<void> addTransfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final transferId = _uuid.v4();
    final title = (note == null || note.trim().isEmpty) ? 'Transfer' : note.trim();
    _transactions.add(Transaction(
      id: _uuid.v4(),
      title: title,
      amount: amount.abs(),
      date: date,
      type: TransactionType.expense,
      categoryId: 'transfer',
      walletId: fromWalletId,
      transferId: transferId,
    ));
    _transactions.add(Transaction(
      id: _uuid.v4(),
      title: title,
      amount: amount.abs(),
      date: date,
      type: TransactionType.income,
      categoryId: 'transfer',
      walletId: toWalletId,
      transferId: transferId,
    ));
    await _persist();
    notifyListeners();
  }

  /// Updates an existing transaction in place, preserving its [id].
  Future<void> updateTransaction({
    required String id,
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String categoryId,
    String? walletId,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _transactions[index] = _transactions[index].copyWith(
      title: title.trim(),
      amount: amount.abs(),
      date: date,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
    );
    await _persist();
    notifyListeners();
  }

  /// Deletes a transaction. If it's one leg of a transfer, the paired leg is
  /// removed too so balances stay correct.
  Future<void> deleteTransaction(String id) async {
    final tx = _transactions.where((t) => t.id == id).firstOrNull;
    if (tx?.transferId != null) {
      _transactions.removeWhere((t) => t.transferId == tx!.transferId);
    } else {
      _transactions.removeWhere((t) => t.id == id);
    }
    await _persist();
    notifyListeners();
  }

  /// Reassigns every transaction in [fromWalletId] to [toWalletId] — used
  /// before deleting a wallet so no transaction is orphaned.
  Future<void> reassignWallet(String fromWalletId, String toWalletId) async {
    for (var i = 0; i < _transactions.length; i++) {
      if (_transactions[i].walletId == fromWalletId) {
        _transactions[i] = _transactions[i].copyWith(walletId: toWalletId);
      }
    }
    await _persist();
    notifyListeners();
  }

  /// Net balance of a wallet in its own currency, derived from its transactions.
  double balanceForWallet(String walletId) {
    return _transactions
        .where((t) => (t.walletId ?? _defaultWalletId) == walletId)
        .fold(0, (sum, t) => sum + t.signedAmount);
  }

  /// Used to attribute pre-wallet transactions to the default wallet so their
  /// balance is still counted. Set by the app once wallets are loaded.
  String? _defaultWalletId;
  set defaultWalletId(String? id) => _defaultWalletId = id;

  /// Re-adds a previously deleted transaction (used by the undo snackbar).
  Future<void> restoreTransaction(Transaction transaction) async {
    _transactions.add(transaction);
    await _persist();
    notifyListeners();
  }

  void selectMonth(DateTime month) {
    _selectedMonth = _firstOfMonth(month);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();
  }

  void setTypeFilter(TransactionType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = null;
    _typeFilter = null;
    notifyListeners();
  }

  /// Serialises every transaction to CSV (real user data, no fabrication).
  String exportCsv() {
    final buffer = StringBuffer('Date,Type,Category,Title,Amount\n');
    for (final t in all) {
      final date = t.date.toIso8601String().split('T').first;
      final category = t.category.label;
      // Escape commas/quotes in the free-text title.
      final title = '"${t.title.replaceAll('"', '""')}"';
      buffer.writeln(
          '$date,${t.type.name},$category,$title,${t.amount.toStringAsFixed(0)}');
    }
    return buffer.toString();
  }

  // ---- Backup hooks ------------------------------------------------------

  List<Map<String, dynamic>> toJsonList() =>
      _transactions.map((t) => t.toJson()).toList();

  /// Replaces all transactions (used by backup restore).
  Future<void> replaceAll(List<Transaction> transactions) async {
    _transactions
      ..clear()
      ..addAll(transactions);
    await _persist();
    notifyListeners();
  }

  // ---- Internals ---------------------------------------------------------

  bool _isInSelectedMonth(DateTime date) =>
      date.year == _selectedMonth.year && date.month == _selectedMonth.month;

  // Transfers move money between the user's own wallets, so they're excluded
  // from income/expense totals and category breakdowns — only genuine income
  // and spending is counted.
  double _incomeFor(DateTime month) => _transactions
      .where((t) =>
          !t.isExpense &&
          !t.isTransfer &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0, (sum, t) => sum + t.amount);

  double _expenseFor(DateTime month) => _transactions
      .where((t) =>
          t.isExpense &&
          !t.isTransfer &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0, (sum, t) => sum + t.amount);

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final encoded = jsonEncode(_transactions.map((t) => t.toJson()).toList());
    await _prefs!.setString(_storageKey, encoded);
  }

  static DateTime _firstOfMonth(DateTime date) => DateTime(date.year, date.month);

  /// Compact label for an amount, kept here to avoid importing the UI layer.
  static String _formatShort(double value) {
    if (value >= 1000000) return 'Rp ${(value / 1000000).toStringAsFixed(1)}jt';
    if (value >= 1000) return 'Rp ${(value / 1000).toStringAsFixed(0)}rb';
    return 'Rp ${value.toStringAsFixed(0)}';
  }
}
