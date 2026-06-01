import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the user's monthly budget limits per category.
///
/// Budgets are a simple `categoryId -> monthly limit` map, persisted locally as
/// JSON. There is no default/fake budget — a category has a budget only when the
/// user sets one. Progress against a budget is computed against real spending
/// (see `ExpenseProvider.expenseForCategory`).
class BudgetProvider extends ChangeNotifier {
  /// [prefs] can be injected in tests; in production it's lazily resolved.
  // ignore: prefer_initializing_formals
  BudgetProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _storageKey = 'budgets';

  SharedPreferences? _prefs;
  final Map<String, double> _budgets = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// An unmodifiable view of all set budgets.
  Map<String, double> get budgets => Map.unmodifiable(_budgets);

  bool get isEmpty => _budgets.isEmpty;

  /// The monthly limit for [categoryId], or `null` if none is set.
  double? limitFor(String categoryId) => _budgets[categoryId];

  /// The sum of all category budgets — the user's total monthly cap.
  double get totalBudget =>
      _budgets.values.fold(0, (sum, value) => sum + value);

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _budgets
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, (v as num).toDouble())));
    }
    _loaded = true;
    notifyListeners();
  }

  /// Sets (or clears, if [limit] is null/<=0) the budget for a category.
  Future<void> setBudget(String categoryId, double? limit) async {
    if (limit == null || limit <= 0) {
      _budgets.remove(categoryId);
    } else {
      _budgets[categoryId] = limit;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _budgets.clear();
    await _persist();
    notifyListeners();
  }

  // ---- Backup hooks ------------------------------------------------------

  Map<String, double> toJson() => Map.of(_budgets);

  /// Replaces all budgets (used by backup restore).
  Future<void> replaceFromJson(Map<String, double> budgets) async {
    _budgets
      ..clear()
      ..addAll(budgets);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(_budgets));
  }
}
