import 'dart:typed_data';

enum ReaderTheme { light, paper, sepia, dark, oled, bedtime }

enum ReaderMode { paginated, continuous, twoPage, focus, fullscreen }

enum AutoThemeMode {
  off('Выкл'),
  system('Системная'),
  sunset('Закат'),
  custom('По времени');

  const AutoThemeMode(this.displayName);
  final String displayName;
}

enum ReaderFont {
  sourceSerif('Source Serif 4'),
  literata('Literata'),
  robotoSerif('Roboto Serif'),
  inter('Inter');

  const ReaderFont(this.displayName);
  final String displayName;
}

enum ReaderTextAlign {
  left('По левому краю'),
  justify('По ширине'),
  center('По центру'),
  right('По правому краю');

  const ReaderTextAlign(this.displayName);
  final String displayName;
}

enum ProgressBarPosition { top, bottom, hidden }

enum BottomBarContent { percent, page, chapter, time, none }

enum TapZoneLayout { third, quarter, edge }

enum PageTurnAnimation { none, slide, fade, curl }

enum ReaderTextDirection { ltr, rtl, auto }

enum DoubleTapAction { toggleUI, addBookmark, toggleFullscreen, disabled }

enum LongPressAction { selectText, addBookmark, openMenu, disabled }

class ReaderSettings {
  final ReaderTheme theme;
  final ReaderMode mode;
  final double fontSize;
  final double lineHeight;
  final double margin;
  final ReaderFont font;
  final double paragraphSpacing;
  final double letterSpacing;
  final ReaderTextAlign textAlign;
  final AutoThemeMode autoThemeMode;
  final int customDayHour;
  final int customNightHour;
  final double brightness;
  final double warmth;
  final bool keepScreenAwake;
  final int autoHideDelay;
  final ProgressBarPosition progressBarPosition;
  final BottomBarContent bottomBarContent;
  final double paragraphFirstLineIndent;
  final bool hyphenation;
  final TapZoneLayout tapZoneLayout;
  final PageTurnAnimation pageTurnAnimation;
  final ReaderTextDirection textDirection;
  final double readerWidth;
  final bool verticalSwipeBrightness;
  final DoubleTapAction doubleTapAction;
  final LongPressAction longPressAction;

  const ReaderSettings({
    this.theme = ReaderTheme.dark,
    this.mode = ReaderMode.continuous,
    this.fontSize = 18.0,
    this.lineHeight = 1.55,
    this.margin = 20.0,
    this.font = ReaderFont.sourceSerif,
    this.paragraphSpacing = 8.0,
    this.letterSpacing = 0.0,
    this.textAlign = ReaderTextAlign.justify,
    this.autoThemeMode = AutoThemeMode.off,
    this.customDayHour = 7,
    this.customNightHour = 20,
    this.brightness = 1.0,
    this.warmth = 0.0,
    this.keepScreenAwake = false,
    this.autoHideDelay = 3,
    this.progressBarPosition = ProgressBarPosition.bottom,
    this.bottomBarContent = BottomBarContent.percent,
    this.paragraphFirstLineIndent = 0.0,
    this.hyphenation = true,
    this.tapZoneLayout = TapZoneLayout.third,
    this.pageTurnAnimation = PageTurnAnimation.slide,
    this.textDirection = ReaderTextDirection.auto,
    this.readerWidth = 820.0,
    this.verticalSwipeBrightness = true,
    this.doubleTapAction = DoubleTapAction.toggleUI,
    this.longPressAction = LongPressAction.selectText,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderMode? mode,
    double? fontSize,
    double? lineHeight,
    double? margin,
    ReaderFont? font,
    double? paragraphSpacing,
    double? letterSpacing,
    ReaderTextAlign? textAlign,
    AutoThemeMode? autoThemeMode,
    int? customDayHour,
    int? customNightHour,
    double? brightness,
    double? warmth,
    bool? keepScreenAwake,
    int? autoHideDelay,
    ProgressBarPosition? progressBarPosition,
    BottomBarContent? bottomBarContent,
    double? paragraphFirstLineIndent,
    bool? hyphenation,
    TapZoneLayout? tapZoneLayout,
    PageTurnAnimation? pageTurnAnimation,
    ReaderTextDirection? textDirection,
    double? readerWidth,
    bool? verticalSwipeBrightness,
    DoubleTapAction? doubleTapAction,
    LongPressAction? longPressAction,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      mode: mode ?? this.mode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
      font: font ?? this.font,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textAlign: textAlign ?? this.textAlign,
      autoThemeMode: autoThemeMode ?? this.autoThemeMode,
      customDayHour: customDayHour ?? this.customDayHour,
      customNightHour: customNightHour ?? this.customNightHour,
      brightness: brightness ?? this.brightness,
      warmth: warmth ?? this.warmth,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      autoHideDelay: autoHideDelay ?? this.autoHideDelay,
      progressBarPosition: progressBarPosition ?? this.progressBarPosition,
      bottomBarContent: bottomBarContent ?? this.bottomBarContent,
      paragraphFirstLineIndent: paragraphFirstLineIndent ?? this.paragraphFirstLineIndent,
      hyphenation: hyphenation ?? this.hyphenation,
      tapZoneLayout: tapZoneLayout ?? this.tapZoneLayout,
      pageTurnAnimation: pageTurnAnimation ?? this.pageTurnAnimation,
      textDirection: textDirection ?? this.textDirection,
      readerWidth: readerWidth ?? this.readerWidth,
      verticalSwipeBrightness: verticalSwipeBrightness ?? this.verticalSwipeBrightness,
      doubleTapAction: doubleTapAction ?? this.doubleTapAction,
      longPressAction: longPressAction ?? this.longPressAction,
    );
  }
}

class ReadingProgress {
  final String bookId;
  final int currentPosition;
  final DateTime lastRead;

  const ReadingProgress({
    required this.bookId,
    required this.currentPosition,
    required this.lastRead,
  });
}

class ReadingProfile {
  final String name;
  final ReaderSettings settings;

  const ReadingProfile({required this.name, required this.settings});

  static const defaults = <ReadingProfile>[
    ReadingProfile(
      name: 'Стандартный',
      settings: ReaderSettings(),
    ),
    ReadingProfile(
      name: 'Комфортный',
      settings: ReaderSettings(
        fontSize: 20.0,
        lineHeight: 1.7,
        margin: 24.0,
        paragraphSpacing: 12.0,
        font: ReaderFont.literata,
        theme: ReaderTheme.sepia,
      ),
    ),
    ReadingProfile(
      name: 'Компактный',
      settings: ReaderSettings(
        fontSize: 14.0,
        lineHeight: 1.3,
        margin: 8.0,
        paragraphSpacing: 4.0,
        letterSpacing: -0.3,
      ),
    ),
    ReadingProfile(
      name: 'Ночной',
      settings: ReaderSettings(
        paragraphSpacing: 10.0,
      ),
    ),
  ];
}

abstract class BookParser {
  Future<String> parseFb2(Uint8List bytes);
  Future<String> parseEpub(Uint8List bytes);
  Future<String> parseTxt(Uint8List bytes);
}
