import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reader.dart';

class ReaderSettingsPersistence {
  static const _key = 'reader_settings';

  static Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return const ReaderSettings();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ReaderSettings(
        theme: ReaderTheme.values.firstWhere(
          (e) => e.name == map['theme'],
          orElse: () => ReaderTheme.system,
        ),
        mode: ReaderMode.values.firstWhere(
          (e) => e.name == map['mode'],
          orElse: () => ReaderMode.auto,
        ),
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.55,
        margin: (map['margin'] as num?)?.toDouble() ?? 16.0,
        font: ReaderFont.values.firstWhere(
          (e) => e.name == map['font'],
          orElse: () => ReaderFont.literata,
        ),
        paragraphSpacing: (map['paragraphSpacing'] as num?)?.toDouble() ?? 8.0,
        letterSpacing: (map['letterSpacing'] as num?)?.toDouble() ?? 0.0,
        textAlign: ReaderTextAlign.values.firstWhere(
          (e) => e.name == map['textAlign'],
          orElse: () => ReaderTextAlign.left,
        ),
        autoThemeMode: AutoThemeMode.values.firstWhere(
          (e) => e.name == map['autoThemeMode'],
          orElse: () => AutoThemeMode.off,
        ),
        customDayHour: (map['customDayHour'] as num?)?.toInt() ?? 7,
        customNightHour: (map['customNightHour'] as num?)?.toInt() ?? 20,
        brightness: (map['brightness'] as num?)?.toDouble() ?? 1.0,
        warmth: (map['warmth'] as num?)?.toDouble() ?? 0.0,
        keepScreenAwake: map['keepScreenAwake'] as bool? ?? true,
        autoHideDelay: (map['autoHideDelay'] as num?)?.toInt() ?? 3,
        progressBarPosition: ProgressBarPosition.values.firstWhere(
          (e) => e.name == map['progressBarPosition'],
          orElse: () => ProgressBarPosition.top,
        ),
        bottomBarContent: BottomBarContent.values.firstWhere(
          (e) => e.name == map['bottomBarContent'],
          orElse: () => BottomBarContent.percent,
        ),
        paragraphFirstLineIndent: (map['paragraphFirstLineIndent'] as num?)?.toDouble() ?? 0.0,
        hyphenation: map['hyphenation'] as bool? ?? true,
        tapZoneLayout: TapZoneLayout.values.firstWhere(
          (e) => e.name == map['tapZoneLayout'],
          orElse: () => TapZoneLayout.quarter,
        ),
        pageTurnAnimation: PageTurnAnimation.values.firstWhere(
          (e) => e.name == map['pageTurnAnimation'],
          orElse: () => PageTurnAnimation.slide,
        ),
        textDirection: ReaderTextDirection.values.firstWhere(
          (e) => e.name == map['textDirection'],
          orElse: () => ReaderTextDirection.auto,
        ),
        readerWidth: (map['readerWidth'] as num?)?.toDouble() ?? 820.0,
        verticalSwipeBrightness: map['verticalSwipeBrightness'] as bool? ?? true,
        doubleTapAction: DoubleTapAction.values.firstWhere(
          (e) => e.name == map['doubleTapAction'],
          orElse: () => DoubleTapAction.toggleUI,
        ),
        longPressAction: LongPressAction.values.firstWhere(
          (e) => e.name == map['longPressAction'],
          orElse: () => LongPressAction.selectText,
        ),
        restoreLastPosition: map['restoreLastPosition'] as bool? ?? true,
      );
    } on Object catch (_) {
      return const ReaderSettings();
    }
  }

  static Future<void> save(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'theme': settings.theme.name,
        'mode': settings.mode.name,
        'fontSize': settings.fontSize,
        'lineHeight': settings.lineHeight,
        'margin': settings.margin,
        'font': settings.font.name,
        'paragraphSpacing': settings.paragraphSpacing,
        'letterSpacing': settings.letterSpacing,
        'textAlign': settings.textAlign.name,
        'autoThemeMode': settings.autoThemeMode.name,
        'customDayHour': settings.customDayHour,
        'customNightHour': settings.customNightHour,
        'brightness': settings.brightness,
        'warmth': settings.warmth,
        'keepScreenAwake': settings.keepScreenAwake,
        'autoHideDelay': settings.autoHideDelay,
        'progressBarPosition': settings.progressBarPosition.name,
        'bottomBarContent': settings.bottomBarContent.name,
        'paragraphFirstLineIndent': settings.paragraphFirstLineIndent,
        'hyphenation': settings.hyphenation,
        'tapZoneLayout': settings.tapZoneLayout.name,
        'pageTurnAnimation': settings.pageTurnAnimation.name,
        'textDirection': settings.textDirection.name,
        'readerWidth': settings.readerWidth,
        'verticalSwipeBrightness': settings.verticalSwipeBrightness,
        'doubleTapAction': settings.doubleTapAction.name,
        'longPressAction': settings.longPressAction.name,
        'restoreLastPosition': settings.restoreLastPosition,
      }),
    );
  }
}
