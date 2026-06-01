import 'package:flutter/material.dart';

/// Centralised Material 3 theming for the app.
///
/// A single warm seed color drives both light and dark schemes, with a handful
/// of component overrides (cards, inputs, buttons) tuned for a soft, modern,
/// eye-friendly look: a warm terracotta/amber palette on warm sand/cream
/// surfaces, generous corner radii, no harsh shadows, and comfortable spacing.
class AppTheme {
  AppTheme._();

  /// Warm terracotta seed — inviting, low-glare, reads well in light and dark.
  static const Color seed = Color(0xFFC2693E);

  /// Warm gradient used by the balance hero card (terracotta → amber → coral).
  static const List<Color> heroGradient = [
    Color(0xFFC2693E),
    Color(0xFFE0894C),
    Color(0xFFE8A05A),
  ];

  /// Semantic colors, kept in the same warm family so nothing clashes.
  static const Color income = Color(0xFF6E8B3D); // warm olive green
  static const Color expense = Color(0xFFC65339); // warm clay red
  static const Color warn = Color(0xFFD98324); // amber, for over-budget

  // Surface colors tuned for warmth and low eye-strain.
  static const Color _lightScaffold = Color(0xFFFBF6F0); // warm cream
  static const Color _lightCard = Color(0xFFFFFDFB); // near-white, warm
  static const Color _darkScaffold = Color(0xFF1C1714); // warm near-black
  static const Color _darkCard = Color(0xFF2A221E); // warm brown-grey

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? _darkScaffold : _lightScaffold,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? _darkScaffold : _lightScaffold,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardColor: isDark ? _darkCard : _lightCard,
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? _darkCard : _lightCard,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkCard : _lightCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineMedium:
          base.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
