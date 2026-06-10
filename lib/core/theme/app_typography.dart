import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _inter({
    required bool isDark,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle displayLarge({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 57, letterSpacing: -0.25);
  }

  static TextStyle displayMedium({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 45);
  }

  static TextStyle displaySmall({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 36);
  }

  static TextStyle headlineLarge({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 32);
  }

  static TextStyle headlineMedium({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 28);
  }

  static TextStyle headlineSmall({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 24);
  }

  static TextStyle titleLarge({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 22, fontWeight: FontWeight.w500);
  }

  static TextStyle titleMedium({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15);
  }

  static TextStyle titleSmall({required bool isDark}) {
    return _inter(isDark: isDark, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  }

  static TextStyle bodyLarge({required bool isDark}) {
    return _inter(isDark: isDark, fontSize: 16, letterSpacing: 0.5);
  }

  static TextStyle bodyMedium({required bool isDark}) {
    return _inter(isDark: isDark, letterSpacing: 0.25);
  }

  static TextStyle bodySmall({required bool isDark}) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      letterSpacing: 0.4,
      color: isDark ? Colors.white70 : Colors.black54,
    );
  }

  static TextStyle readerBody({
    required bool isDark,
    double fontSize = 18,
    String? fontFamily,
  }) {
    final font = _mapReaderFont(fontFamily ?? 'Literata');
    return TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      height: 1.6,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle readerTitle({
    required bool isDark,
    double fontSize = 24,
    String? fontFamily,
  }) {
    final font = _mapReaderFont(fontFamily ?? 'Literata');
    return TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle readerChapter({
    required bool isDark,
    double fontSize = 20,
    String? fontFamily,
  }) {
    final font = _mapReaderFont(fontFamily ?? 'Literata');
    return TextStyle(
      fontFamily: font,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static String _mapReaderFont(String fontFamily) {
    switch (fontFamily) {
      case 'Merriweather':
      case 'Source Serif 4':
      case 'Source Serif':
        return 'SourceSerif4';
      case 'Roboto Serif':
        return 'RobotoSerif';
      case 'Literata':
      default:
        return 'Literata';
    }
  }

  static const List<String> availableReaderFonts = [
    'Literata',
    'Source Serif 4',
    'Roboto Serif',
    'Inter',
  ];
}
