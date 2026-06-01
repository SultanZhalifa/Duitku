import 'package:flutter/material.dart';

/// A spending/income category with a stable [id], a display [label],
/// an [icon] and a [color] used across the UI and charts.
///
/// Categories are a fixed, curated set rather than user-editable, which keeps
/// the demo focused and the chart legend readable.
class Category {
  const Category({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  // Warm, eye-friendly palette: earthy clay, terracotta, amber, olive, ochre
  // and muted rose. Distinct enough to read in the chart, harmonious together.
  static const List<Category> all = [
    Category(id: 'food', label: 'Food & Drink', icon: Icons.restaurant, color: Color(0xFFC65339)),
    Category(id: 'transport', label: 'Transport', icon: Icons.directions_bus, color: Color(0xFFCF9447)),
    Category(id: 'shopping', label: 'Shopping', icon: Icons.shopping_bag, color: Color(0xFFB76E79)),
    Category(id: 'bills', label: 'Bills', icon: Icons.receipt_long, color: Color(0xFFD98324)),
    Category(id: 'health', label: 'Health', icon: Icons.favorite, color: Color(0xFFA8584F)),
    Category(id: 'entertainment', label: 'Entertainment', icon: Icons.movie, color: Color(0xFF9C6644)),
    Category(id: 'salary', label: 'Salary', icon: Icons.payments, color: Color(0xFF6E8B3D)),
    Category(id: 'other', label: 'Other', icon: Icons.category, color: Color(0xFF8D7B68)),
    Category(id: 'transfer', label: 'Transfer', icon: Icons.swap_horiz, color: Color(0xFF6E8B3D)),
  ];

  /// Categories shown in the add/edit picker — excludes the internal
  /// `transfer` category, which is only created by wallet transfers.
  static List<Category> get selectable =>
      all.where((c) => c.id != 'transfer').toList();

  static const Category fallback =
      Category(id: 'other', label: 'Other', icon: Icons.category, color: Color(0xFF8D7B68));

  /// Resolves a category by [id], returning [fallback] if it's unknown
  /// (e.g. data saved by an older version of the app).
  static Category byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => fallback);
  }
}
