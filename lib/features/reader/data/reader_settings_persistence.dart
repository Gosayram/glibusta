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
          orElse: () => ReaderMode.paginated,
        ),
        twoPageEnabled: map['twoPageEnabled'] as bool? ?? false,
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18.0,
        lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.6,
        margin: (map['margin'] as num?)?.toDouble() ?? 20.0,
        marginTop: (map['marginTop'] as num?)?.toDouble() ?? 20.0,
        marginBottom: (map['marginBottom'] as num?)?.toDouble() ?? 20.0,
        marginLeft: (map['marginLeft'] as num?)?.toDouble() ?? 20.0,
        marginRight: (map['marginRight'] as num?)?.toDouble() ?? 20.0,
        separateMargins: map['separateMargins'] as bool? ?? false,
        font: ReaderFont.values.firstWhere(
          (e) => e.name == map['font'],
          orElse: () => ReaderFont.literata,
        ),
        paragraphSpacing: (map['paragraphSpacing'] as num?)?.toDouble() ?? 20.0,
        letterSpacing: (map['letterSpacing'] as num?)?.toDouble() ?? 0.0,
        wordSpacing: (map['wordSpacing'] as num?)?.toDouble() ?? 0.0,
        fontWeightDelta: (map['fontWeightDelta'] as num?)?.toDouble() ?? 0.0,
        textAlign: ReaderTextAlign.values.firstWhere(
          (e) => e.name == map['textAlign'],
          orElse: () => ReaderTextAlign.justify,
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
        paragraphFirstLineIndent: (map['paragraphFirstLineIndent'] as num?)?.toDouble() ?? 16.0,
        paragraphIndentMode: ParagraphIndentMode.values.firstWhere(
          (e) => e.name == map['paragraphIndentMode'],
          orElse: () => ParagraphIndentMode.firstLine,
        ),
        hyphenation: map['hyphenation'] as bool? ?? true,
        oldStyleFigures: map['oldStyleFigures'] as bool? ?? false,
        smallCaps: map['smallCaps'] as bool? ?? false,
        rsvpWpm: ((map['rsvpWpm'] as num?)?.toInt() ?? 300).clamp(100, 1000),
        ignoreBookAlignment: map['ignoreBookAlignment'] as bool? ?? false,
        ignoreBookIndent: map['ignoreBookIndent'] as bool? ?? false,
        pageTurnAnimation: PageTurnAnimation.values.firstWhere(
          (e) => e.name == map['pageTurnAnimation'],
          orElse: () => PageTurnAnimation.slide,
        ),
        scrollInertia: ScrollInertia.values.firstWhere(
          (e) => e.name == map['scrollInertia'],
          orElse: () => ScrollInertia.medium,
        ),
        textDirection: ReaderTextDirection.values.firstWhere(
          (e) => e.name == map['textDirection'],
          orElse: () => ReaderTextDirection.auto,
        ),
        readerWidth: (map['readerWidth'] as num?)?.toDouble() ?? 820.0,
        verticalSwipeBrightness: map['verticalSwipeBrightness'] as bool? ?? true,
        pageTurnHaptic: map['pageTurnHaptic'] as bool? ?? false,
        twoFingerChapterNavigation: map['twoFingerChapterNavigation'] as bool? ?? false,
        doubleTapAction: DoubleTapAction.values.firstWhere(
          (e) => e.name == map['doubleTapAction'],
          orElse: () => DoubleTapAction.toggleUI,
        ),
        longPressAction: LongPressAction.values.firstWhere(
          (e) => e.name == map['longPressAction'],
          orElse: () => LongPressAction.selectText,
        ),
        topLeftCornerTapAction: CornerTapAction.values.firstWhere(
          (e) => e.name == map['topLeftCornerTapAction'],
          orElse: () => CornerTapAction.inherit,
        ),
        topRightCornerTapAction: CornerTapAction.values.firstWhere(
          (e) => e.name == map['topRightCornerTapAction'],
          orElse: () => CornerTapAction.inherit,
        ),
        bottomLeftCornerTapAction: CornerTapAction.values.firstWhere(
          (e) => e.name == map['bottomLeftCornerTapAction'],
          orElse: () => CornerTapAction.inherit,
        ),
        bottomRightCornerTapAction: CornerTapAction.values.firstWhere(
          (e) => e.name == map['bottomRightCornerTapAction'],
          orElse: () => CornerTapAction.inherit,
        ),
        restoreLastPosition: map['restoreLastPosition'] as bool? ?? true,
        forcedEncoding: map['forcedEncoding'] as String?,
        horizontalGesture: HorizontalGesture.values.firstWhere(
          (e) => e.name == map['horizontalGesture'],
          orElse: () => HorizontalGesture.on,
        ),
        horizontalGestureScroll: HorizontalGestureScroll.values.firstWhere(
          (e) => e.name == map['horizontalGestureScroll'],
          orElse: () => HorizontalGestureScroll.half,
        ),
        tapZoneWidth: (map['tapZoneWidth'] as num?)?.toDouble() ?? 0.33,
        fullScreenMode: FullScreenMode.values.firstWhere(
          (e) => e.name == map['fullScreenMode'],
          orElse: () => FullScreenMode.immersive,
        ),
        customCss: map['customCss'] as String? ?? '',
        perceptionExpander: map['perceptionExpander'] as bool? ?? false,
        hideBarsOnFastScroll: map['hideBarsOnFastScroll'] as bool? ?? false,
        orientationLock: OrientationLock.values.firstWhere(
          (e) => e.name == map['orientationLock'],
          orElse: () => OrientationLock.none,
        ),
        bionicReading: map['bionicReading'] as bool? ?? false,
        horizontalLimiter: map['horizontalLimiter'] as bool? ?? false,
        horizontalLimiterHeight: (map['horizontalLimiterHeight'] as num?)?.toDouble() ?? 0.5,
        horizontalLimiterOffset: (map['horizontalLimiterOffset'] as num?)?.toDouble() ?? 0.5,
        horizontalLimiterDimming: (map['horizontalLimiterDimming'] as num?)?.toDouble() ?? 0.15,
        horizontalLimiterLines: map['horizontalLimiterLines'] as bool? ?? true,
        scrollbarIndicator: map['scrollbarIndicator'] as bool? ?? true,
        showImages: map['showImages'] as bool? ?? true,
        imageCornerRadius: (map['imageCornerRadius'] as num?)?.toDouble() ?? 0.0,
        imageAlignment: ImageAlignment.values.firstWhere(
          (e) => e.name == map['imageAlignment'],
          orElse: () => ImageAlignment.center,
        ),
        imageWidth: (map['imageWidth'] as num?)?.toDouble() ?? 1.0,
        imageColorEffect: ImageColorEffect.values.firstWhere(
          (e) => e.name == map['imageColorEffect'],
          orElse: () => ImageColorEffect.off,
        ),
        activeColorPresetId: map['activeColorPresetId'] as String? ?? 'blue_light',
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
        'twoPageEnabled': settings.twoPageEnabled,
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
        'paragraphIndentMode': settings.paragraphIndentMode.name,
        'hyphenation': settings.hyphenation,
        'oldStyleFigures': settings.oldStyleFigures,
        'smallCaps': settings.smallCaps,
        'rsvpWpm': settings.rsvpWpm,
        'ignoreBookAlignment': settings.ignoreBookAlignment,
        'ignoreBookIndent': settings.ignoreBookIndent,
        'pageTurnAnimation': settings.pageTurnAnimation.name,
        'scrollInertia': settings.scrollInertia.name,
        'textDirection': settings.textDirection.name,
        'readerWidth': settings.readerWidth,
        'verticalSwipeBrightness': settings.verticalSwipeBrightness,
        'pageTurnHaptic': settings.pageTurnHaptic,
        'twoFingerChapterNavigation': settings.twoFingerChapterNavigation,
        'doubleTapAction': settings.doubleTapAction.name,
        'longPressAction': settings.longPressAction.name,
        'topLeftCornerTapAction': settings.topLeftCornerTapAction.name,
        'topRightCornerTapAction': settings.topRightCornerTapAction.name,
        'bottomLeftCornerTapAction': settings.bottomLeftCornerTapAction.name,
        'bottomRightCornerTapAction': settings.bottomRightCornerTapAction.name,
        'restoreLastPosition': settings.restoreLastPosition,
        'forcedEncoding': settings.forcedEncoding,
        'horizontalGesture': settings.horizontalGesture.name,
        'horizontalGestureScroll': settings.horizontalGestureScroll.name,
        'tapZoneWidth': settings.tapZoneWidth,
        'fullScreenMode': settings.fullScreenMode.name,
        'customCss': settings.customCss,
        'perceptionExpander': settings.perceptionExpander,
        'hideBarsOnFastScroll': settings.hideBarsOnFastScroll,
        'orientationLock': settings.orientationLock.name,
        'bionicReading': settings.bionicReading,
        'horizontalLimiter': settings.horizontalLimiter,
        'horizontalLimiterHeight': settings.horizontalLimiterHeight,
        'horizontalLimiterOffset': settings.horizontalLimiterOffset,
        'horizontalLimiterDimming': settings.horizontalLimiterDimming,
        'horizontalLimiterLines': settings.horizontalLimiterLines,
        'scrollbarIndicator': settings.scrollbarIndicator,
        'showImages': settings.showImages,
        'imageCornerRadius': settings.imageCornerRadius,
        'imageAlignment': settings.imageAlignment.name,
        'imageWidth': settings.imageWidth,
        'imageColorEffect': settings.imageColorEffect.name,
        'activeColorPresetId': settings.activeColorPresetId,
      }),
    );
  }
}
