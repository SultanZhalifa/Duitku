import 'package:intl/intl.dart';

import '../models/currency.dart';

/// Shared formatting helpers so currency and dates look consistent everywhere.
class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 1,
  );

  /// e.g. `Rp 320.000` — the app's base currency (IDR).
  static String currency(double value) => _currency.format(value);

  /// Formats [value] using an arbitrary [currency]'s symbol and precision,
  /// e.g. `$ 12.50` or `Rp 320.000`. Used for per-wallet amounts.
  static String currencyIn(double value, Currency currency) {
    return NumberFormat.currency(
      symbol: '${currency.symbol} ',
      decimalDigits: currency.decimalDigits,
    ).format(value);
  }

  /// e.g. `Rp 8,5 jt` — used where space is tight (chart labels, summary).
  static String compactCurrency(double value) => _compact.format(value);

  /// e.g. `June 2026`
  static String monthYear(DateTime date) => DateFormat.yMMMM().format(date);

  /// e.g. `Jun 2026`
  static String shortMonthYear(DateTime date) =>
      DateFormat('MMM yyyy').format(date);

  /// e.g. `Mon, 3 Jun`
  static String dayLabel(DateTime date) => DateFormat('EEE, d MMM').format(date);
}
