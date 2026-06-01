import 'package:flutter/material.dart';

/// A money container the user holds funds in (cash, a bank account, an e-wallet)
/// in a specific currency.
///
/// A wallet stores no balance of its own — its balance is derived from the
/// transactions assigned to it, so the two can never drift out of sync.
@immutable
class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.colorValue,
    required this.iconCodePoint,
    this.rateToBase = 1.0,
  });

  final String id;
  final String name;
  final String currencyCode;

  /// Stored as an int so the model serialises cleanly to JSON.
  final int colorValue;
  final int iconCodePoint;

  /// How many units of the base currency one unit of this wallet's currency is
  /// worth. Entered by the user; defaults to 1.0 (i.e. same as base).
  final double rateToBase;

  Color get color => Color(colorValue);

  /// Resolves the icon from the fixed [iconChoices] set by matching code point,
  /// so icons stay tree-shakeable (no dynamically constructed [IconData]).
  IconData get icon => iconChoices.firstWhere(
        (i) => i.codePoint == iconCodePoint,
        orElse: () => Icons.account_balance_wallet,
      );

  Wallet copyWith({
    String? name,
    String? currencyCode,
    int? colorValue,
    int? iconCodePoint,
    double? rateToBase,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      rateToBase: rateToBase ?? this.rateToBase,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currencyCode': currencyCode,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'rateToBase': rateToBase,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      currencyCode: json['currencyCode'] as String? ?? 'IDR',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6E8B3D,
      iconCodePoint:
          (json['iconCodePoint'] as num?)?.toInt() ?? Icons.wallet.codePoint,
      rateToBase: (json['rateToBase'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Icon choices offered when creating/editing a wallet.
  static const List<IconData> iconChoices = [
    Icons.account_balance_wallet,
    Icons.account_balance,
    Icons.payments,
    Icons.credit_card,
    Icons.savings,
    Icons.phone_iphone,
    Icons.attach_money,
    Icons.qr_code,
  ];

  /// Color choices (warm palette) offered when creating/editing a wallet.
  static const List<int> colorChoices = [
    0xFFC2693E,
    0xFF6E8B3D,
    0xFFD98324,
    0xFFB76E79,
    0xFF9C6644,
    0xFF8D7B68,
  ];
}
