import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primaryColor = Color(0xFF6750A4);
  static const _darkPrimaryColor = Color(0xFFD0BCFF);

  static final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
    ),
    useMaterial3: true,
  );

  static final darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimaryColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  // Reader-specific themes
  static const readerDayBackground = Color(0xFFF8F1E3);
  static const readerNightBackground = Color(0xFF111318);
  static const readerSepiaBackground = Color(0xFFF4ECD8);

  static final readerDayTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
    ),
    scaffoldBackgroundColor: readerDayBackground,
    useMaterial3: true,
  );

  static final readerNightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: readerNightBackground,
    useMaterial3: true,
  );

  static final readerSepiaTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B7355),
    ),
    scaffoldBackgroundColor: readerSepiaBackground,
    useMaterial3: true,
  );
}
