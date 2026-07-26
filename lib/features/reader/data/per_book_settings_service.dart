import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/per_book_settings_dao.dart';
import '../domain/reader.dart';
import 'reader_settings_persistence.dart';

final perBookSettingsDaoProvider = Provider<PerBookSettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return PerBookSettingsDao(db);
});

final perBookSettingsServiceProvider = Provider<PerBookSettingsService>((ref) {
  final dao = ref.watch(perBookSettingsDaoProvider);
  return PerBookSettingsService(dao);
});

class PerBookSettingsService {
  PerBookSettingsService(this._dao);

  final PerBookSettingsDao _dao;

  Future<ReaderSettings> getEffectiveSettings(String bookId) async {
    final global = await ReaderSettingsPersistence.load();
    final perBook = await _dao.getSettings(bookId);
    if (perBook == null) return global;
    return mergeReaderSettings(global, perBook);
  }

  Future<void> saveBookSetting({
    required String bookId,
    required String key,
    required dynamic value,
  }) async {
    final existing = await _dao.getSettings(bookId) ?? {};
    existing[key] = value;
    await _dao.saveSettings(bookId, existing);
  }

  /// Saves the reading appearance as one per-book update, leaving global
  /// defaults and non-appearance settings untouched.
  Future<void> saveReadingAppearance(String bookId, ReaderSettings settings) async {
    final existing = await _dao.getSettings(bookId) ?? {};
    existing.addAll(readingAppearanceOverrides(settings));
    await _dao.saveSettings(bookId, existing);
  }

  Future<void> resetToGlobal(String bookId) async {
    await _dao.deleteSettings(bookId);
  }

  Future<bool> hasPerBookSettings(String bookId) async {
    final settings = await _dao.getSettings(bookId);
    return settings != null && settings.isNotEmpty;
  }
}

/// Merges sparse per-book settings over the complete global reader profile.
///
/// Per-book settings are intentionally sparse: a book-specific font size, for
/// example, must not reset unrelated global preferences such as gestures,
/// typography, or image handling.
@visibleForTesting
ReaderSettings mergeReaderSettings(ReaderSettings global, Map<String, dynamic> overrides) {
  return global.copyWith(
    theme: _enumOverride(overrides, 'theme', ReaderTheme.values, global.theme),
    mode: _enumOverride(overrides, 'mode', ReaderMode.values, global.mode),
    twoPageEnabled: _boolOverride(overrides, 'twoPageEnabled', global.twoPageEnabled),
    fontSize: _doubleOverride(overrides, 'fontSize', global.fontSize),
    lineHeight: _doubleOverride(overrides, 'lineHeight', global.lineHeight),
    margin: _doubleOverride(overrides, 'margin', global.margin),
    marginTop: _doubleOverride(overrides, 'marginTop', global.marginTop),
    marginBottom: _doubleOverride(overrides, 'marginBottom', global.marginBottom),
    marginLeft: _doubleOverride(overrides, 'marginLeft', global.marginLeft),
    marginRight: _doubleOverride(overrides, 'marginRight', global.marginRight),
    separateMargins: _boolOverride(overrides, 'separateMargins', global.separateMargins),
    font: _enumOverride(overrides, 'font', ReaderFont.values, global.font),
    paragraphSpacing: _doubleOverride(overrides, 'paragraphSpacing', global.paragraphSpacing),
    letterSpacing: _doubleOverride(overrides, 'letterSpacing', global.letterSpacing),
    wordSpacing: _doubleOverride(overrides, 'wordSpacing', global.wordSpacing),
    fontWeightDelta: _doubleOverride(overrides, 'fontWeightDelta', global.fontWeightDelta),
    textAlign: _enumOverride(overrides, 'textAlign', ReaderTextAlign.values, global.textAlign),
    autoThemeMode: _enumOverride(
      overrides,
      'autoThemeMode',
      AutoThemeMode.values,
      global.autoThemeMode,
    ),
    customDayHour: _intOverride(overrides, 'customDayHour', global.customDayHour),
    customNightHour: _intOverride(overrides, 'customNightHour', global.customNightHour),
    brightness: _doubleOverride(overrides, 'brightness', global.brightness),
    warmth: _doubleOverride(overrides, 'warmth', global.warmth),
    keepScreenAwake: _boolOverride(overrides, 'keepScreenAwake', global.keepScreenAwake),
    autoHideDelay: _intOverride(overrides, 'autoHideDelay', global.autoHideDelay),
    progressBarPosition: _enumOverride(
      overrides,
      'progressBarPosition',
      ProgressBarPosition.values,
      global.progressBarPosition,
    ),
    bottomBarContent: _enumOverride(
      overrides,
      'bottomBarContent',
      BottomBarContent.values,
      global.bottomBarContent,
    ),
    paragraphFirstLineIndent: _doubleOverride(
      overrides,
      'paragraphFirstLineIndent',
      global.paragraphFirstLineIndent,
    ),
    paragraphIndentMode: _enumOverride(
      overrides,
      'paragraphIndentMode',
      ParagraphIndentMode.values,
      global.paragraphIndentMode,
    ),
    hyphenation: _boolOverride(overrides, 'hyphenation', global.hyphenation),
    pageTurnAnimation: _enumOverride(
      overrides,
      'pageTurnAnimation',
      PageTurnAnimation.values,
      global.pageTurnAnimation,
    ),
    scrollInertia: _enumOverride(
      overrides,
      'scrollInertia',
      ScrollInertia.values,
      global.scrollInertia,
    ),
    textDirection: _enumOverride(
      overrides,
      'textDirection',
      ReaderTextDirection.values,
      global.textDirection,
    ),
    readerWidth: _doubleOverride(overrides, 'readerWidth', global.readerWidth),
    verticalSwipeBrightness: _boolOverride(
      overrides,
      'verticalSwipeBrightness',
      global.verticalSwipeBrightness,
    ),
    doubleTapAction: _enumOverride(
      overrides,
      'doubleTapAction',
      DoubleTapAction.values,
      global.doubleTapAction,
    ),
    longPressAction: _enumOverride(
      overrides,
      'longPressAction',
      LongPressAction.values,
      global.longPressAction,
    ),
    restoreLastPosition: _boolOverride(
      overrides,
      'restoreLastPosition',
      global.restoreLastPosition,
    ),
    forcedEncoding: _stringOverride(overrides, 'forcedEncoding', global.forcedEncoding),
    horizontalGesture: _enumOverride(
      overrides,
      'horizontalGesture',
      HorizontalGesture.values,
      global.horizontalGesture,
    ),
    horizontalGestureScroll: _enumOverride(
      overrides,
      'horizontalGestureScroll',
      HorizontalGestureScroll.values,
      global.horizontalGestureScroll,
    ),
    tapZoneWidth: _doubleOverride(overrides, 'tapZoneWidth', global.tapZoneWidth),
    fullScreenMode: _enumOverride(
      overrides,
      'fullScreenMode',
      FullScreenMode.values,
      global.fullScreenMode,
    ),
    customCss: _stringOverride(overrides, 'customCss', global.customCss) ?? global.customCss,
    perceptionExpander: _boolOverride(
      overrides,
      'perceptionExpander',
      global.perceptionExpander,
    ),
    hideBarsOnFastScroll: _boolOverride(
      overrides,
      'hideBarsOnFastScroll',
      global.hideBarsOnFastScroll,
    ),
    orientationLock: _enumOverride(
      overrides,
      'orientationLock',
      OrientationLock.values,
      global.orientationLock,
    ),
    bionicReading: _boolOverride(overrides, 'bionicReading', global.bionicReading),
    horizontalLimiter: _boolOverride(overrides, 'horizontalLimiter', global.horizontalLimiter),
    horizontalLimiterHeight: _doubleOverride(
      overrides,
      'horizontalLimiterHeight',
      global.horizontalLimiterHeight,
    ),
    horizontalLimiterOffset: _doubleOverride(
      overrides,
      'horizontalLimiterOffset',
      global.horizontalLimiterOffset,
    ),
    horizontalLimiterDimming: _doubleOverride(
      overrides,
      'horizontalLimiterDimming',
      global.horizontalLimiterDimming,
    ),
    horizontalLimiterLines: _boolOverride(
      overrides,
      'horizontalLimiterLines',
      global.horizontalLimiterLines,
    ),
    scrollbarIndicator: _boolOverride(overrides, 'scrollbarIndicator', global.scrollbarIndicator),
    showImages: _boolOverride(overrides, 'showImages', global.showImages),
    imageCornerRadius: _doubleOverride(
      overrides,
      'imageCornerRadius',
      global.imageCornerRadius,
    ),
    imageAlignment: _enumOverride(
      overrides,
      'imageAlignment',
      ImageAlignment.values,
      global.imageAlignment,
    ),
    imageWidth: _doubleOverride(overrides, 'imageWidth', global.imageWidth),
    imageColorEffect: _enumOverride(
      overrides,
      'imageColorEffect',
      ImageColorEffect.values,
      global.imageColorEffect,
    ),
    activeColorPresetId:
        _stringOverride(overrides, 'activeColorPresetId', global.activeColorPresetId) ??
        global.activeColorPresetId,
    oldStyleFigures: _boolOverride(overrides, 'oldStyleFigures', global.oldStyleFigures),
    smallCaps: _boolOverride(overrides, 'smallCaps', global.smallCaps),
    rsvpWpm: _intOverride(overrides, 'rsvpWpm', global.rsvpWpm),
    ignoreBookAlignment: _boolOverride(
      overrides,
      'ignoreBookAlignment',
      global.ignoreBookAlignment,
    ),
    ignoreBookIndent: _boolOverride(overrides, 'ignoreBookIndent', global.ignoreBookIndent),
  );
}

@visibleForTesting
Map<String, dynamic> readingAppearanceOverrides(ReaderSettings settings) => {
  'theme': settings.theme.name,
  'fontSize': settings.fontSize,
  'lineHeight': settings.lineHeight,
  'margin': settings.margin,
  'marginTop': settings.marginTop,
  'marginBottom': settings.marginBottom,
  'marginLeft': settings.marginLeft,
  'marginRight': settings.marginRight,
  'separateMargins': settings.separateMargins,
  'font': settings.font.name,
  'paragraphSpacing': settings.paragraphSpacing,
  'letterSpacing': settings.letterSpacing,
  'wordSpacing': settings.wordSpacing,
  'fontWeightDelta': settings.fontWeightDelta,
  'textAlign': settings.textAlign.name,
  'paragraphFirstLineIndent': settings.paragraphFirstLineIndent,
  'paragraphIndentMode': settings.paragraphIndentMode.name,
};

T _enumOverride<T extends Enum>(
  Map<String, dynamic> overrides,
  String key,
  List<T> values,
  T fallback,
) {
  final name = overrides[key];
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

bool _boolOverride(Map<String, dynamic> overrides, String key, bool fallback) =>
    overrides[key] is bool ? overrides[key] as bool : fallback;

double _doubleOverride(Map<String, dynamic> overrides, String key, double fallback) {
  final value = overrides[key];
  return value is num ? value.toDouble() : fallback;
}

int _intOverride(Map<String, dynamic> overrides, String key, int fallback) {
  final value = overrides[key];
  return value is num ? value.toInt() : fallback;
}

String? _stringOverride(Map<String, dynamic> overrides, String key, String? fallback) =>
    overrides[key] is String ? overrides[key] as String : fallback;
