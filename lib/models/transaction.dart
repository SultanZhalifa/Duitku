import 'category.dart';

/// Whether a transaction adds money (income) or removes it (expense).
enum TransactionType { income, expense }

/// A single money movement: an amount, a category, a note and a date.
///
/// Immutable by design — edits create a new instance via [copyWith], which
/// keeps state changes explicit and easy to reason about.
///
/// A wallet-to-wallet transfer is modelled as two linked legs (an expense in
/// the source wallet and an income in the destination), sharing a [transferId].
/// This keeps every existing total/chart calculation correct without special
/// casing, while still letting the UI recognise and group transfers.
class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    this.walletId,
    this.transferId,
  });

  final String id;
  final String title;

  /// Always stored as a positive number. The sign is derived from [type].
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;

  /// The wallet this transaction belongs to. Nullable for data created before
  /// wallets existed; such transactions are treated as the default wallet.
  final String? walletId;

  /// Non-null when this transaction is one leg of a transfer. Both legs share
  /// the same value so they can be grouped, edited, and deleted together.
  final String? transferId;

  bool get isExpense => type == TransactionType.expense;
  bool get isTransfer => transferId != null;

  /// The signed value: negative for expenses, positive for income.
  double get signedAmount => isExpense ? -amount : amount;

  Category get category => Category.byId(categoryId);

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    String? transferId,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      transferId: transferId ?? this.transferId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type.name,
        'categoryId': categoryId,
        if (walletId != null) 'walletId': walletId,
        if (transferId != null) 'transferId': transferId,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      type: TransactionType.values.byName(json['type'] as String),
      categoryId: json['categoryId'] as String,
      walletId: json['walletId'] as String?,
      transferId: json['transferId'] as String?,
    );
  }
}
