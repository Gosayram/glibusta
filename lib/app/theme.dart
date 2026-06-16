import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

part 'theme.g.dart';

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) => state = mode;
}

class AppTheme {
  AppTheme._();

  static const FlexScheme _scheme = FlexScheme.deepPurple;

  static const _subThemesData = FlexSubThemesData(
    blendOnLevel: 10,
    useMaterial3Typography: true,
    useM2StyleDividerInM3: true,
    interactionEffects: true,
    tintedDisabledControls: true,
    adaptiveRemoveElevationTint: FlexAdaptive.all(),
    defaultRadius: AppRadius.md,
    thickBorderWidth: 2,
    thinBorderWidth: 1,
    inputDecoratorRadius: AppRadius.sm,
    inputDecoratorSchemeColor: SchemeColor.primary,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
    navigationBarIndicatorOpacity: 0.15,
    navigationBarIndicatorRadius: AppRadius.sm,
    cardRadius: AppRadius.md,
    cardBackgroundSchemeColor: SchemeColor.surfaceContainerLow,
    cardBorderSchemeColor: SchemeColor.outlineVariant,
    cardBorderWidth: 1,
    dialogRadius: AppRadius.lg,
    dialogBackgroundSchemeColor: SchemeColor.surfaceContainerHigh,
    bottomSheetRadius: AppRadius.xl,
    bottomSheetClipBehavior: Clip.antiAlias,
    bottomSheetBackgroundColor: SchemeColor.surfaceContainerLow,
    snackBarRadius: AppRadius.sm,
    snackBarElevation: 6,
    snackBarBackgroundSchemeColor: SchemeColor.inverseSurface,
    snackBarActionSchemeColor: SchemeColor.inversePrimary,
    tooltipRadius: AppRadius.xs,
    tooltipWaitDuration: Duration(milliseconds: 400),
    tooltipShowDuration: Duration(milliseconds: 2000),
    tooltipSchemeColor: SchemeColor.inverseSurface,
    tooltipOpacity: 0.9,
    chipRadius: AppRadius.xs,
    chipSchemeColor: SchemeColor.secondary,
    chipSelectedSchemeColor: SchemeColor.primary,
    searchBarRadius: AppRadius.lg,
    searchViewRadius: AppRadius.lg,
    searchUseGlobalShape: true,
    progressIndicatorBaseSchemeColor: SchemeColor.primary,
    progressIndicatorStrokeWidth: 3,
    progressIndicatorStrokeCap: StrokeCap.round,
    sliderBaseSchemeColor: SchemeColor.primary,
    sliderYear2023: true,
    switchAdaptiveCupertinoLike: FlexAdaptive.all(),
    fabRadius: AppRadius.lg,
    fabSchemeColor: SchemeColor.primaryContainer,
    fabForegroundSchemeColor: SchemeColor.onPrimaryContainer,
    listTileTileSchemeColor: SchemeColor.surface,
    listTileSelectedTileSchemeColor: SchemeColor.primaryContainer,
  );

  static const _darkSubThemesData = FlexSubThemesData(
    blendOnLevel: 20,
    useMaterial3Typography: true,
    useM2StyleDividerInM3: true,
    interactionEffects: true,
    tintedDisabledControls: true,
    adaptiveRemoveElevationTint: FlexAdaptive.all(),
    defaultRadius: AppRadius.md,
    thickBorderWidth: 2,
    thinBorderWidth: 1,
    inputDecoratorRadius: AppRadius.sm,
    inputDecoratorSchemeColor: SchemeColor.primary,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
    navigationBarIndicatorOpacity: 0.15,
    navigationBarIndicatorRadius: AppRadius.sm,
    cardRadius: AppRadius.md,
    cardBackgroundSchemeColor: SchemeColor.surfaceContainerLow,
    cardBorderSchemeColor: SchemeColor.outlineVariant,
    cardBorderWidth: 1,
    dialogRadius: AppRadius.lg,
    dialogBackgroundSchemeColor: SchemeColor.surfaceContainerHigh,
    bottomSheetRadius: AppRadius.xl,
    bottomSheetClipBehavior: Clip.antiAlias,
    bottomSheetBackgroundColor: SchemeColor.surfaceContainerLow,
    snackBarRadius: AppRadius.sm,
    snackBarElevation: 6,
    snackBarBackgroundSchemeColor: SchemeColor.inverseSurface,
    snackBarActionSchemeColor: SchemeColor.inversePrimary,
    tooltipRadius: AppRadius.xs,
    tooltipWaitDuration: Duration(milliseconds: 400),
    tooltipShowDuration: Duration(milliseconds: 2000),
    tooltipSchemeColor: SchemeColor.inverseSurface,
    tooltipOpacity: 0.9,
    chipRadius: AppRadius.xs,
    chipSchemeColor: SchemeColor.secondary,
    chipSelectedSchemeColor: SchemeColor.primary,
    searchBarRadius: AppRadius.lg,
    searchViewRadius: AppRadius.lg,
    searchUseGlobalShape: true,
    progressIndicatorBaseSchemeColor: SchemeColor.primary,
    progressIndicatorStrokeWidth: 3,
    progressIndicatorStrokeCap: StrokeCap.round,
    sliderBaseSchemeColor: SchemeColor.primary,
    sliderYear2023: true,
    switchAdaptiveCupertinoLike: FlexAdaptive.all(),
    fabRadius: AppRadius.lg,
    fabSchemeColor: SchemeColor.primaryContainer,
    fabForegroundSchemeColor: SchemeColor.onPrimaryContainer,
    listTileTileSchemeColor: SchemeColor.surface,
    listTileSelectedTileSchemeColor: SchemeColor.primaryContainer,
  );

  static final lightTheme = FlexThemeData.light(
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
      useError: true,
    ),
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: _subThemesData,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    swapLegacyOnMaterial3: true,
    fontFamily: 'Inter',
  );

  static final darkTheme = FlexThemeData.dark(
    keyColors: const FlexKeyColors(
      useSecondary: true,
      useTertiary: true,
      useError: true,
    ),
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: _darkSubThemesData,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    swapLegacyOnMaterial3: true,
    fontFamily: 'Inter',
  );

  static final readerDayTheme =
      FlexThemeData.light(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: _subThemesData,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: 'Inter',
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerDay,
      );

  static final readerNightTheme =
      FlexThemeData.dark(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: _darkSubThemesData,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: 'Inter',
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerNight,
      );

  static final readerSepiaTheme =
      FlexThemeData.light(
        scheme: FlexScheme.gold,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: _subThemesData,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: 'Inter',
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
          interactionEffects: true,
          tintedDisabledControls: true,
          adaptiveRemoveElevationTint: FlexAdaptive.all(),
          defaultRadius: AppRadius.md,
          cardRadius: AppRadius.md,
          dialogRadius: AppRadius.lg,
          bottomSheetRadius: AppRadius.xl,
          snackBarRadius: AppRadius.sm,
          tooltipRadius: AppRadius.xs,
          chipRadius: AppRadius.xs,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: 'Inter',
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerOledBlack,
      );

  static final readerPaperTheme =
      FlexThemeData.light(
        scheme: _scheme,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: _subThemesData,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        swapLegacyOnMaterial3: true,
        fontFamily: 'Inter',
      ).copyWith(
        scaffoldBackgroundColor: AppColors.readerPaper,
      );

  static ThemeMode getReaderThemeMode(String themeName) {
    switch (themeName) {
      case 'night':
      case 'oledBlack':
        return ThemeMode.dark;
      case 'sepia':
      case 'paper':
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
