import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(0xFF01472f),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(0xFF01472f),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: colorScheme,
      inputDecorationTheme: _inputDecorationTheme(colorScheme),
      useMaterial3: true,
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12));

    return InputDecorationTheme(
      border: border,
      enabledBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    );
  }
}
