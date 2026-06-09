import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  // FlexColorScheme scheme
  static const FlexScheme _scheme = FlexScheme.deepPurple;

  // Light theme
  static final lightTheme = FlexThemeData.light(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
  );

  // Dark theme
  static final darkTheme = FlexThemeData.dark(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
  );

  // Reader-specific themes
  static final readerDayTheme =
      FlexThemeData.light(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          useMaterial3Typography: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerDay,
      );

  static final readerNightTheme =
      FlexThemeData.dark(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useMaterial3Typography: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerNight,
      );

  static final readerSepiaTheme =
      FlexThemeData.light(
        scheme: FlexScheme.gold,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          useMaterial3Typography: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerSepia,
      );

  static final readerOledBlackTheme =
      FlexThemeData.dark(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 0,
          useMaterial3Typography: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerOledBlack,
      );

  static final readerPaperTheme =
      FlexThemeData.light(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          useMaterial3Typography: true,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerPaper,
      );

  // Reader theme enum
  static ThemeMode getReaderThemeMode(String themeName) {
    switch (themeName) {
      case 'night':
      case 'oledBlack':
        return ThemeMode.dark;
      case 'sepia':
      case 'paper':
        return ThemeMode.light;
      case 'day':
      default:
        return ThemeMode.light;
    }
  }

  static ThemeData getReaderTheme(String themeName) {
    switch (themeName) {
      case 'night':
        return readerNightTheme;
      case 'sepia':
        return readerSepiaTheme;
      case 'oledBlack':
        return readerOledBlackTheme;
      case 'paper':
        return readerPaperTheme;
      case 'day':
      default:
        return readerDayTheme;
    }
  }
}
