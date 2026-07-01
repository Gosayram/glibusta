import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader.freezed.dart';

enum ReaderTheme { system, light, paper, sepia, dark, oled, bedtime }

enum ReaderMode { paginated, continuous }

enum ReaderLoadingStage {
  openingFile('Открытие файла...'),
  readingMetadata('Разбор книги...'),
  loadingChapters('Загрузка глав...'),
  restoringPosition('Восстановление позиции...');

  const ReaderLoadingStage(this.message);
  final String message;
}

enum AutoThemeMode {
  off('Выкл'),
  system('Системная'),
  sunset('Закат'),
  custom('По времени');

  const AutoThemeMode(this.displayName);
  final String displayName;
}

enum ReaderFont {
  literata('Literata'),
  inter('Inter'),
  serif('Serif'),
  sans('Sans-Serif'),
  mono('Monospace'),
  system('Системный');

  const ReaderFont(this.displayName);
  final String displayName;

  String get fontFamily => switch (this) {
    ReaderFont.literata => 'Literata',
    ReaderFont.inter => 'Inter',
    ReaderFont.serif => 'serif',
    ReaderFont.sans => 'sans-serif',
    ReaderFont.mono => 'monospace',
    ReaderFont.system => '',
  };
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

enum PageTurnAnimation { none, slide, fade, curl }

enum ReaderTextDirection { ltr, rtl, auto }

enum DoubleTapAction { toggleUI, addBookmark, translate, disabled }

enum LongPressAction { selectText, addBookmark, openMenu, disabled }

enum HorizontalGesture { off, on, inverse }

enum HorizontalGestureScroll { half, twoThirds, threeQuarters }

enum OrientationLock { none, portrait, landscape }

enum ImageAlignment { start, center, end }

enum ImageColorEffect { off, grayscale, fontColor, backgroundColor }

enum ParagraphIndentMode {
  asInBook('Как в книге'),
  firstLine('Первая строка'),
  emptyLine('Пустая строка'),
  custom('Свой отступ');

  const ParagraphIndentMode(this.displayName);
  final String displayName;
}

@freezed
abstract class ReaderSettings with _$ReaderSettings {
  const factory ReaderSettings({
    @Default(ReaderTheme.system) ReaderTheme theme,
    @Default(ReaderMode.paginated) ReaderMode mode,
    @Default(false) bool twoPageEnabled,
    @Default(18.0) double fontSize,
    @Default(1.6) double lineHeight,
    @Default(20.0) double margin,
    @Default(false) bool separateMargins,
    @Default(ReaderFont.literata) ReaderFont font,
    @Default(20.0) double paragraphSpacing,
    @Default(0.0) double letterSpacing,
    @Default(0.0) double wordSpacing,
    @Default(0.0) double fontWeightDelta,
    @Default(ReaderTextAlign.justify) ReaderTextAlign textAlign,
    @Default(AutoThemeMode.off) AutoThemeMode autoThemeMode,
    @Default(7) int customDayHour,
    @Default(20) int customNightHour,
    @Default(1.0) double brightness,
    @Default(0.0) double warmth,
    @Default(true) bool keepScreenAwake,
    @Default(3) int autoHideDelay,
    @Default(ProgressBarPosition.top) ProgressBarPosition progressBarPosition,
    @Default(BottomBarContent.percent) BottomBarContent bottomBarContent,
    @Default(16.0) double paragraphFirstLineIndent,
    @Default(ParagraphIndentMode.firstLine) ParagraphIndentMode paragraphIndentMode,
    @Default(true) bool hyphenation,
    @Default(PageTurnAnimation.slide) PageTurnAnimation pageTurnAnimation,
    @Default(ReaderTextDirection.auto) ReaderTextDirection textDirection,
    @Default(820.0) double readerWidth,
    @Default(true) bool verticalSwipeBrightness,
    @Default(DoubleTapAction.toggleUI) DoubleTapAction doubleTapAction,
    @Default(LongPressAction.selectText) LongPressAction longPressAction,
    @Default(true) bool restoreLastPosition,
    String? forcedEncoding,
    @Default(HorizontalGesture.on) HorizontalGesture horizontalGesture,
    @Default(HorizontalGestureScroll.half) HorizontalGestureScroll horizontalGestureScroll,
    @Default(false) bool perceptionExpander,
    @Default(false) bool hideBarsOnFastScroll,
    @Default(OrientationLock.none) OrientationLock orientationLock,
    @Default(false) bool bionicReading,
    @Default(false) bool horizontalLimiter,
    @Default(0.5) double horizontalLimiterHeight,
    @Default(0.5) double horizontalLimiterOffset,
    @Default(0.15) double horizontalLimiterDimming,
    @Default(true) bool horizontalLimiterLines,
    @Default(true) bool scrollbarIndicator,
    @Default(true) bool showImages,
    @Default(0.0) double imageCornerRadius,
    @Default(ImageAlignment.center) ImageAlignment imageAlignment,
    @Default(1.0) double imageWidth,
    @Default(ImageColorEffect.off) ImageColorEffect imageColorEffect,
    @Default('blue_light') String activeColorPresetId,
  }) = _ReaderSettings;
}

@freezed
abstract class ReaderPosition with _$ReaderPosition {
  const factory ReaderPosition({
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    @Default(0.0) double localOffset,
    @Default(0.0) double progressPercent,
    @Default('') String chapterId,
    @Default(0) int textOffset,
    required DateTime updatedAt,
  }) = _ReaderPosition;
  const ReaderPosition._();

  static final initial = ReaderPosition(
    bookId: '',
    chapterIndex: 0,
    paragraphIndex: 0,
    updatedAt: DateTime(2000),
  );

  int get currentPosition => chapterIndex;

  ReaderPosition clamp({required int chapterCount}) {
    if (chapterCount <= 0) {
      return ReaderPosition(
        bookId: bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: updatedAt,
      );
    }
    final lastChapter = chapterCount <= 1 ? 0 : chapterCount - 1;
    return ReaderPosition(
      bookId: bookId,
      chapterIndex: chapterIndex.clamp(0, lastChapter),
      paragraphIndex: paragraphIndex < 0 ? 0 : paragraphIndex,
      localOffset: localOffset.clamp(0.0, 100.0),
      progressPercent: progressPercent.clamp(0.0, 1.0),
      chapterId: chapterId,
      textOffset: textOffset,
      updatedAt: updatedAt,
    );
  }
}

class ReadingProgress {
  final ReaderPosition position;
  final int totalPages;
  final DateTime lastRead;

  const ReadingProgress({
    required this.position,
    required this.totalPages,
    required this.lastRead,
  });

  factory ReadingProgress.fromPosition(ReaderPosition position, {required int totalPages}) {
    return ReadingProgress(
      position: position,
      totalPages: totalPages,
      lastRead: position.updatedAt,
    );
  }
}
