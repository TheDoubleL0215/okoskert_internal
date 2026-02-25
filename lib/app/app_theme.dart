import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightGreen,
      brightness: Brightness.light,
    ),
    inputDecorationTheme: _inputDecorationTheme(),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightGreen,
      brightness: Brightness.dark,
    ),
    inputDecorationTheme: _inputDecorationTheme(),
    useMaterial3: true,
  );

  static InputDecorationTheme _inputDecorationTheme() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return InputDecorationTheme(
      border: border,
      enabledBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
