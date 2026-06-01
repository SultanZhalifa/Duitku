import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/currency.dart';
import '../models/wallet.dart';

/// Owns the user's wallets and the app's base currency.
///
/// Wallet balances are NOT stored here — they're derived from transactions by
/// `ExpenseProvider`, so balances can never drift from reality. On first run a
/// single default "Cash" wallet in the base currency is created so transactions
/// always have somewhere to live; this is real setup state, not demo data.
class WalletProvider extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  WalletProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _walletsKey = 'wallets';
  static const _baseCurrencyKey = 'base_currency';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;
  final List<Wallet> _wallets = [];
  String _baseCurrencyCode = 'IDR';

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Wallet> get wallets => List.unmodifiable(_wallets);
  String get baseCurrencyCode => _baseCurrencyCode;
  Currency get baseCurrency => Currency.byCode(_baseCurrencyCode);

  /// The wallet new transactions default to (the first one).
  Wallet? get defaultWallet => _wallets.isEmpty ? null : _wallets.first;

  Wallet? walletById(String? id) {
    if (id == null) return defaultWallet;
    for (final w in _wallets) {
      if (w.id == id) return w;
    }
    return defaultWallet;
  }

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _baseCurrencyCode = _prefs!.getString(_baseCurrencyKey) ?? 'IDR';

    final raw = _prefs!.getString(_walletsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _wallets
        ..clear()
        ..addAll(decoded.map((e) => Wallet.fromJson(e as Map<String, dynamic>)));
    }

    // Ensure there's always at least one wallet to assign transactions to.
    if (_wallets.isEmpty) {
      _wallets.add(Wallet(
        id: _uuid.v4(),
        name: 'Cash',
        currencyCode: _baseCurrencyCode,
        colorValue: Wallet.colorChoices.first,
        iconCodePoint: Wallet.iconChoices.first.codePoint,
      ));
      await _persist();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<Wallet> addWallet({
    required String name,
    required String currencyCode,
    required int colorValue,
    required int iconCodePoint,
    double rateToBase = 1.0,
  }) async {
    final wallet = Wallet(
      id: _uuid.v4(),
      name: name.trim(),
      currencyCode: currencyCode,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      rateToBase: rateToBase,
    );
    _wallets.add(wallet);
    await _persist();
    notifyListeners();
    return wallet;
  }

  Future<void> updateWallet(Wallet wallet) async {
    final index = _wallets.indexWhere((w) => w.id == wallet.id);
    if (index == -1) return;
    _wallets[index] = wallet;
    await _persist();
    notifyListeners();
  }

  /// Removes a wallet. The caller is responsible for reassigning or deleting any
  /// transactions that referenced it. The last remaining wallet can't be
  /// removed, so transactions always have a home.
  Future<bool> removeWallet(String id) async {
    if (_wallets.length <= 1) return false;
    _wallets.removeWhere((w) => w.id == id);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> setBaseCurrency(String code) async {
    _baseCurrencyCode = code;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_baseCurrencyKey, code);
    notifyListeners();
  }

  /// Converts [amount] held in [wallet]'s currency into the base currency using
  /// the user-entered rate. Pure arithmetic — no external/fake market data.
  double toBase(double amount, Wallet wallet) => amount * wallet.rateToBase;

  // ---- Backup hooks ------------------------------------------------------

  List<Map<String, dynamic>> toJsonList() =>
      _wallets.map((w) => w.toJson()).toList();

  /// Replaces all wallets (used by backup restore). Falls back to a default
  /// wallet if the imported list is empty.
  Future<void> replaceAll(List<Wallet> wallets, String baseCurrencyCode) async {
    _baseCurrencyCode = baseCurrencyCode;
    _wallets
      ..clear()
      ..addAll(wallets);
    if (_wallets.isEmpty) {
      _wallets.add(Wallet(
        id: _uuid.v4(),
        name: 'Cash',
        currencyCode: _baseCurrencyCode,
        colorValue: Wallet.colorChoices.first,
        iconCodePoint: Wallet.iconChoices.first.codePoint,
      ));
    }
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_baseCurrencyKey, _baseCurrencyCode);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    final encoded = jsonEncode(_wallets.map((w) => w.toJson()).toList());
    await _prefs!.setString(_walletsKey, encoded);
  }
}
