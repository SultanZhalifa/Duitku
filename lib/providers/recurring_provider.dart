import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import 'expense_provider.dart';

/// Owns recurring-transaction rules and materialises the real transactions they
/// generate.
///
/// On every [catchUp] (called at startup) the provider walks each active rule's
/// schedule forward from `nextDue` up to today, creating a genuine
/// [Transaction] for each missed occurrence via [ExpenseProvider]. Nothing is
/// faked — these are normal transactions the user can edit or delete, and the
/// rule's `nextDue` is advanced and persisted so an occurrence is never created
/// twice.
class RecurringProvider extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  RecurringProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'recurring_rules';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;
  final List<RecurringRule> _rules = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<RecurringRule> get rules =>
      List.unmodifiable([..._rules]..sort((a, b) => a.nextDue.compareTo(b.nextDue)));

  bool get isEmpty => _rules.isEmpty;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _rules
        ..clear()
        ..addAll(
            decoded.map((e) => RecurringRule.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  /// Generates any transactions that have come due since the app was last open.
  /// Returns the number of transactions created so the UI can inform the user.
  Future<int> catchUp(ExpenseProvider expenses, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    var created = 0;
    var changed = false;

    for (var i = 0; i < _rules.length; i++) {
      var rule = _rules[i];
      if (!rule.active) continue;

      // Safety bound to avoid pathological loops on bad data.
      var guard = 0;
      while (!rule.nextDue.isAfter(today) && guard < 1000) {
        await expenses.addRaw(Transaction(
          id: _uuid.v4(),
          title: rule.title,
          amount: rule.amount,
          date: rule.nextDue,
          type: rule.type,
          categoryId: rule.categoryId,
          walletId: rule.walletId,
        ));
        created++;
        rule = rule.copyWith(nextDue: rule.advance(rule.nextDue));
        guard++;
      }

      if (rule.nextDue != _rules[i].nextDue) {
        _rules[i] = rule;
        changed = true;
      }
    }

    if (changed) await _persist();
    if (created > 0) notifyListeners();
    return created;
  }

  Future<void> addRule({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String? walletId,
    required Frequency frequency,
    required DateTime startDate,
  }) async {
    _rules.add(RecurringRule(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount.abs(),
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      frequency: frequency,
      startDate: startDate,
      nextDue: startDate,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> toggleActive(String id, bool active) async {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _rules[index] = _rules[index].copyWith(active: active);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _persist();
    notifyListeners();
  }

  // ---- Backup hooks ------------------------------------------------------

  List<Map<String, dynamic>> toJsonList() =>
      _rules.map((r) => r.toJson()).toList();

  Future<void> replaceAll(List<RecurringRule> rules) async {
    _rules
      ..clear()
      ..addAll(rules);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
        _storageKey, jsonEncode(_rules.map((r) => r.toJson()).toList()));
  }
}
