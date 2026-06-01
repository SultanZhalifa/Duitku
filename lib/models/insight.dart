import 'package:flutter/material.dart';

/// A single, human-readable insight computed from real transaction data.
///
/// Insights are never fabricated: each one is produced by [ExpenseProvider]
/// only when the underlying data supports the statement (e.g. a month-over-month
/// comparison is omitted entirely when there's no previous-month data).
@immutable
class Insight {
  const Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
}
