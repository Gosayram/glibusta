import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reader.dart';

class ReaderSettingsPersistence {
  static const _key = 'reader_settings';

  static num? _num(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

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
        fontSize: (_num(map['fontSize']))?.toDouble() ?? 18.0,
        noteFontSize: (_num(map['noteFontSize']))?.toDouble(),
        lineHeight: (_num(map['lineHeight']))?.toDouble() ?? 1.6,
        margin: (_num(map['margin']))?.toDouble() ?? 20.0,
        marginTop: (_num(map['marginTop']))?.toDouble() ?? 20.0,
        marginBottom: (_num(map['marginBottom']))?.toDouble() ?? 20.0,
        marginLeft: (_num(map['marginLeft']))?.toDouble() ?? 20.0,
        marginRight: (_num(map['marginRight']))?.toDouble() ?? 20.0,
        separateMargins: map['separateMargins'] as bool? ?? false,
        marginAsPercent: map['marginAsPercent'] as bool? ?? false,
        font: ReaderFont.values.firstWhere(
          (e) => e.name == map['font'],
          orElse: () => ReaderFont.literata,
        ),
        paragraphSpacing: (_num(map['paragraphSpacing']))?.toDouble() ?? 20.0,
        letterSpacing: (_num(map['letterSpacing']))?.toDouble() ?? 0.0,
        wordSpacing: (_num(map['wordSpacing']))?.toDouble() ?? 0.0,
        fontWeightDelta: (_num(map['fontWeightDelta']))?.toDouble() ?? 0.0,
        textAlign: ReaderTextAlign.values.firstWhere(
          (e) => e.name == map['textAlign'],
          orElse: () => ReaderTextAlign.justify,
        ),
        autoThemeMode: AutoThemeMode.values.firstWhere(
          (e) => e.name == map['autoThemeMode'],
          orElse: () => AutoThemeMode.off,
        ),
        nightTheme: ReaderTheme.values.firstWhere(
          (e) => e.name == map['nightTheme'],
          orElse: () => ReaderTheme.dark,
        ),
        customDayHour: ((_num(map['customDayHour']))?.toInt() ?? 7).clamp(0, 23),
        customNightHour: ((_num(map['customNightHour']))?.toInt() ?? 20).clamp(0, 23),
        brightness: (_num(map['brightness']))?.toDouble() ?? 1.0,
        warmth: (_num(map['warmth']))?.toDouble() ?? 0.0,
        keepScreenAwake: map['keepScreenAwake'] as bool? ?? true,
        autoHideDelay: ((_num(map['autoHideDelay']))?.toInt() ?? 3).clamp(0, 60),
        progressBarPosition: ProgressBarPosition.values.firstWhere(
          (e) => e.name == map['progressBarPosition'],
          orElse: () => ProgressBarPosition.top,
        ),
        bottomBarContent: BottomBarContent.values.firstWhere(
          (e) => e.name == map['bottomBarContent'],
          orElse: () => BottomBarContent.percent,
        ),
        paragraphFirstLineIndent: (_num(map['paragraphFirstLineIndent']))?.toDouble() ?? 16.0,
        paragraphIndentMode: ParagraphIndentMode.values.firstWhere(
          (e) => e.name == map['paragraphIndentMode'],
          orElse: () => ParagraphIndentMode.firstLine,
        ),
        hyphenation: map['hyphenation'] as bool? ?? true,
        oldStyleFigures: map['oldStyleFigures'] as bool? ?? false,
        smallCaps: map['smallCaps'] as bool? ?? false,
        rsvpWpm: ((_num(map['rsvpWpm']))?.toInt() ?? 300).clamp(100, 1000),
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
        readerWidth: (_num(map['readerWidth']))?.toDouble() ?? 820.0,
        verticalSwipeBrightness: map['verticalSwipeBrightness'] as bool? ?? true,
        pageTurnHaptic: map['pageTurnHaptic'] as bool? ?? false,
        twoFingerChapterNavigation: map['twoFingerChapterNavigation'] as bool? ?? false,
        volumeButtonsEnabled: map['volumeButtonsEnabled'] as bool? ?? false,
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
        topLeftCornerLongPressAction: CornerLongPressAction.values.firstWhere(
          (e) => e.name == map['topLeftCornerLongPressAction'],
          orElse: () => CornerLongPressAction.inherit,
        ),
        topRightCornerLongPressAction: CornerLongPressAction.values.firstWhere(
          (e) => e.name == map['topRightCornerLongPressAction'],
          orElse: () => CornerLongPressAction.inherit,
        ),
        bottomLeftCornerLongPressAction: CornerLongPressAction.values.firstWhere(
          (e) => e.name == map['bottomLeftCornerLongPressAction'],
          orElse: () => CornerLongPressAction.inherit,
        ),
        bottomRightCornerLongPressAction: CornerLongPressAction.values.firstWhere(
          (e) => e.name == map['bottomRightCornerLongPressAction'],
          orElse: () => CornerLongPressAction.inherit,
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
        tapZoneWidth: (_num(map['tapZoneWidth']))?.toDouble() ?? 0.33,
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
        horizontalLimiterHeight: (_num(map['horizontalLimiterHeight']))?.toDouble() ?? 0.5,
        horizontalLimiterOffset: (_num(map['horizontalLimiterOffset']))?.toDouble() ?? 0.5,
        horizontalLimiterDimming: (_num(map['horizontalLimiterDimming']))?.toDouble() ?? 0.15,
        horizontalLimiterLines: map['horizontalLimiterLines'] as bool? ?? true,
        scrollbarIndicator: map['scrollbarIndicator'] as bool? ?? true,
        scrollSnap: map['scrollSnap'] as bool? ?? false,
        showImages: map['showImages'] as bool? ?? true,
        imageCornerRadius: (_num(map['imageCornerRadius']))?.toDouble() ?? 0.0,
        imageAlignment: ImageAlignment.values.firstWhere(
          (e) => e.name == map['imageAlignment'],
          orElse: () => ImageAlignment.center,
        ),
        imageWidth: (_num(map['imageWidth']))?.toDouble() ?? 1.0,
        imageColorEffect: ImageColorEffect.values.firstWhere(
          (e) => e.name == map['imageColorEffect'],
          orElse: () => ImageColorEffect.off,
        ),
        activeColorPresetId: map['activeColorPresetId'] as String? ?? 'blue_light',
        eink: map['eink'] as bool? ?? false,
        showTopInfoBar: map['showTopInfoBar'] as bool? ?? true,
        showTopToolbar: map['showTopToolbar'] as bool? ?? true,
        showBottomBar: map['showBottomBar'] as bool? ?? true,
        backgroundStyle: BackgroundStyle.values.firstWhere(
          (e) => e.name == map['backgroundStyle'],
          orElse: () => BackgroundStyle.solid,
        ),
        uiTheme: map['uiTheme'] != null
            ? ReaderTheme.values.firstWhere(
                (e) => e.name == map['uiTheme'],
                orElse: () => ReaderTheme.system,
              )
            : null,
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
        'noteFontSize': settings.noteFontSize,
        'lineHeight': settings.lineHeight,
        'margin': settings.margin,
        'marginTop': settings.marginTop,
        'marginBottom': settings.marginBottom,
        'marginLeft': settings.marginLeft,
        'marginRight': settings.marginRight,
        'separateMargins': settings.separateMargins,
        'marginAsPercent': settings.marginAsPercent,
        'font': settings.font.name,
        'paragraphSpacing': settings.paragraphSpacing,
        'letterSpacing': settings.letterSpacing,
        'wordSpacing': settings.wordSpacing,
        'fontWeightDelta': settings.fontWeightDelta,
        'textAlign': settings.textAlign.name,
        'autoThemeMode': settings.autoThemeMode.name,
        'nightTheme': settings.nightTheme.name,
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
        'volumeButtonsEnabled': settings.volumeButtonsEnabled,
        'doubleTapAction': settings.doubleTapAction.name,
        'longPressAction': settings.longPressAction.name,
        'topLeftCornerTapAction': settings.topLeftCornerTapAction.name,
        'topRightCornerTapAction': settings.topRightCornerTapAction.name,
        'bottomLeftCornerTapAction': settings.bottomLeftCornerTapAction.name,
        'bottomRightCornerTapAction': settings.bottomRightCornerTapAction.name,
        'topLeftCornerLongPressAction': settings.topLeftCornerLongPressAction.name,
        'topRightCornerLongPressAction': settings.topRightCornerLongPressAction.name,
        'bottomLeftCornerLongPressAction': settings.bottomLeftCornerLongPressAction.name,
        'bottomRightCornerLongPressAction': settings.bottomRightCornerLongPressAction.name,
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
        'scrollSnap': settings.scrollSnap,
        'showImages': settings.showImages,
        'imageCornerRadius': settings.imageCornerRadius,
        'imageAlignment': settings.imageAlignment.name,
        'imageWidth': settings.imageWidth,
        'imageColorEffect': settings.imageColorEffect.name,
        'activeColorPresetId': settings.activeColorPresetId,
        'eink': settings.eink,
        'showTopInfoBar': settings.showTopInfoBar,
        'showTopToolbar': settings.showTopToolbar,
        'showBottomBar': settings.showBottomBar,
        'backgroundStyle': settings.backgroundStyle.name,
        if (settings.uiTheme != null) 'uiTheme': settings.uiTheme!.name,
      }),
    );
  }
}
