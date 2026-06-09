import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  // App-wide text styles
  static TextStyle displayLarge({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle displayMedium({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle displaySmall({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle headlineLarge({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle headlineMedium({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle headlineSmall({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle titleLarge({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle titleMedium({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle titleSmall({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle bodyLarge({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle bodyMedium({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle bodySmall({required bool isDark}) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: isDark ? Colors.white70 : Colors.black54,
    );
  }

  // Reader-specific typography (serif fonts for better reading experience)
  static TextStyle readerBody({
    required bool isDark,
    double fontSize = 18,
    String? fontFamily,
  }) {
    final font = fontFamily ?? 'Literata';
    return _getReaderFont(font).copyWith(
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
    final font = fontFamily ?? 'Literata';
    return _getReaderFont(font).copyWith(
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
    final font = fontFamily ?? 'Literata';
    return _getReaderFont(font).copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle _getReaderFont(String fontFamily) {
    switch (fontFamily) {
      case 'Merriweather':
        return GoogleFonts.merriweather();
      case 'Source Serif':
        return GoogleFonts.sourceSerif4();
      case 'Roboto Serif':
        return GoogleFonts.robotoSerif();
      case 'Literata':
      default:
        return GoogleFonts.literata();
    }
  }

  // Available reader fonts
  static const List<String> availableReaderFonts = [
    'Literata',
    'Merriweather',
    'Source Serif',
    'Roboto Serif',
  ];
}
