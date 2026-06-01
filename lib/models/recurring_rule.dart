import 'transaction.dart';

/// How often a recurring transaction repeats.
enum Frequency { daily, weekly, monthly }

extension FrequencyLabel on Frequency {
  String get label => switch (this) {
        Frequency.daily => 'Daily',
        Frequency.weekly => 'Weekly',
        Frequency.monthly => 'Monthly',
      };
}

/// A template that generates real transactions on a schedule (e.g. salary on
/// the 1st, a streaming subscription monthly).
///
/// The rule tracks [nextDue]; `RecurringProvider` walks the schedule forward and
/// materialises a concrete [Transaction] for every occurrence that has come due,
/// then advances [nextDue]. Generated transactions are ordinary, fully real
/// entries — nothing is simulated.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    this.active = true,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String? walletId;
  final Frequency frequency;
  final DateTime startDate;

  /// The next date an occurrence should be generated for.
  final DateTime nextDue;
  final bool active;

  /// Returns the date that follows [from] for this rule's frequency.
  DateTime advance(DateTime from) {
    return switch (frequency) {
      Frequency.daily => from.add(const Duration(days: 1)),
      Frequency.weekly => from.add(const Duration(days: 7)),
      Frequency.monthly => DateTime(from.year, from.month + 1, from.day),
    };
  }

  RecurringRule copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    Frequency? frequency,
    DateTime? startDate,
    DateTime? nextDue,
    bool? active,
  }) {
    return RecurringRule(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDue: nextDue ?? this.nextDue,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'categoryId': categoryId,
        'walletId': walletId,
        'frequency': frequency.name,
        'startDate': startDate.toIso8601String(),
        'nextDue': nextDue.toIso8601String(),
        'active': active,
      };

  factory RecurringRule.fromJson(Map<String, dynamic> json) {
    return RecurringRule(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.byName(json['type'] as String),
      categoryId: json['categoryId'] as String,
      walletId: json['walletId'] as String?,
      frequency: Frequency.values.byName(json['frequency'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      nextDue: DateTime.parse(json['nextDue'] as String),
      active: json['active'] as bool? ?? true,
    );
  }
}
