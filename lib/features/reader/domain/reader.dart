import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader.freezed.dart';

enum ReaderTheme { system, light, paper, sepia, dark, oled, bedtime }

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
  literata('Literata'),
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

@freezed
abstract class ReaderSettings with _$ReaderSettings {
  const factory ReaderSettings({
    @Default(ReaderTheme.system) ReaderTheme theme,
    @Default(ReaderMode.continuous) ReaderMode mode,
    @Default(18.0) double fontSize,
    @Default(1.55) double lineHeight,
    @Default(20.0) double margin,
    @Default(ReaderFont.literata) ReaderFont font,
    @Default(8.0) double paragraphSpacing,
    @Default(0.0) double letterSpacing,
    @Default(ReaderTextAlign.left) ReaderTextAlign textAlign,
    @Default(AutoThemeMode.off) AutoThemeMode autoThemeMode,
    @Default(7) int customDayHour,
    @Default(20) int customNightHour,
    @Default(1.0) double brightness,
    @Default(0.0) double warmth,
    @Default(true) bool keepScreenAwake,
    @Default(3) int autoHideDelay,
    @Default(ProgressBarPosition.top) ProgressBarPosition progressBarPosition,
    @Default(BottomBarContent.percent) BottomBarContent bottomBarContent,
    @Default(0.0) double paragraphFirstLineIndent,
    @Default(true) bool hyphenation,
    @Default(TapZoneLayout.third) TapZoneLayout tapZoneLayout,
    @Default(PageTurnAnimation.slide) PageTurnAnimation pageTurnAnimation,
    @Default(ReaderTextDirection.auto) ReaderTextDirection textDirection,
    @Default(820.0) double readerWidth,
    @Default(true) bool verticalSwipeBrightness,
    @Default(DoubleTapAction.toggleUI) DoubleTapAction doubleTapAction,
    @Default(LongPressAction.selectText) LongPressAction longPressAction,
    @Default(true) bool restoreLastPosition,
    String? forcedEncoding,
  }) = _ReaderSettings;
}

class ReaderPosition {
  static final initial = ReaderPosition(
    bookId: '',
    chapterIndex: 0,
    paragraphIndex: 0,
    updatedAt: DateTime(2000),
  );

  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final double localOffset;
  final double progressPercent;
  final DateTime updatedAt;

  const ReaderPosition({
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    this.localOffset = 0.0,
    this.progressPercent = 0.0,
    required this.updatedAt,
  });

  int get currentPosition => chapterIndex;

  ReaderPosition copyWith({
    String? bookId,
    int? chapterIndex,
    int? paragraphIndex,
    double? localOffset,
    double? progressPercent,
    DateTime? updatedAt,
  }) {
    return ReaderPosition(
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      localOffset: localOffset ?? this.localOffset,
      progressPercent: progressPercent ?? this.progressPercent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ReaderPosition clamp({required int chapterCount}) {
    final lastChapter = chapterCount <= 1 ? 0 : chapterCount - 1;
    return ReaderPosition(
      bookId: bookId,
      chapterIndex: chapterIndex.clamp(0, lastChapter),
      paragraphIndex: paragraphIndex < 0 ? 0 : paragraphIndex,
      localOffset: localOffset.clamp(0.0, 100.0),
      progressPercent: progressPercent.clamp(0.0, 1.0),
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
