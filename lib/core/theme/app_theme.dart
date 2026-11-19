import 'package:flutter/material.dart';

/// App-wide Material 3 theme. Follows the system light/dark mode until the
/// settings screen (Phase 5) adds a manual override.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF00696F);

  static ThemeData light() => _base(ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark() => _base(ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ));

  static ThemeData _base(ColorScheme scheme) => ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          centerTitle: false,
        ),
      );
}
