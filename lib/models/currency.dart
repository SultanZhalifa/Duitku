/// A supported currency with its ISO code, symbol and decimal precision.
///
/// Rates are not bundled here — exchange rates are owned (and editable) by the
/// user via `WalletProvider`, so there are no hard-coded/fake market rates. The
/// app simply converts using whatever rate the user has entered relative to the
/// base currency.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    this.decimalDigits = 0,
  });

  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  static const List<Currency> all = [
    Currency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
    Currency(code: 'USD', symbol: r'$', name: 'US Dollar', decimalDigits: 2),
    Currency(code: 'EUR', symbol: '€', name: 'Euro', decimalDigits: 2),
    Currency(code: 'SGD', symbol: r'S$', name: 'Singapore Dollar', decimalDigits: 2),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound', decimalDigits: 2),
    Currency(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', decimalDigits: 2),
    Currency(code: 'AUD', symbol: r'A$', name: 'Australian Dollar', decimalDigits: 2),
  ];

  static const Currency fallback =
      Currency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah');

  static Currency byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => fallback);
}
