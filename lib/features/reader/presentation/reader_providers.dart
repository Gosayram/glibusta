import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/reader_settings_persistence.dart';
import '../domain/reader.dart';

part 'reader_providers.g.dart';

// NOTE: ReaderSettingsNotifier intentionally uses the unawaited(_loadFromPrefs())
// pattern instead of AsyncNotifier. Migration would require updating 18+ consumer
// sites and 25+ setters to handle AsyncValue. The default ReaderSettings() is a
// reasonable fallback — the flash is brief. Migrate if Riverpod adds auto-unwrapping.
@riverpod
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  Timer? _saveDebouncer;

  @override
  ReaderSettings build() {
    _loadFromPrefs();
    listenSelf((prev, next) {
      if (prev != next) {
        _saveDebouncer?.cancel();
        _saveDebouncer = Timer(const Duration(milliseconds: 300), () {
          unawaited(ReaderSettingsPersistence.save(next));
        });
      }
    });
    ref.onDispose(() => _saveDebouncer?.cancel());
    return const ReaderSettings();
  }

  void _loadFromPrefs() {
    unawaited(
      ReaderSettingsPersistence.load().then((settings) {
        if (state == const ReaderSettings()) {
          state = settings;
        }
      }),
    );
  }

  void updateTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
  }

  void updateTwoPageEnabled(bool enabled) {
    state = state.copyWith(twoPageEnabled: enabled);
  }

  void updateFont(ReaderFont font) {
    state = state.copyWith(font: font);
  }

  void updateLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight);
  }

  void updateMargin(double margin) {
    state = state.copyWith(margin: margin);
  }

  void updateSeparateMargins(bool enabled) {
    state = state.copyWith(separateMargins: enabled);
  }

  void updateMarginTop(double value) {
    state = state.copyWith(marginTop: value);
  }

  void updateMarginBottom(double value) {
    state = state.copyWith(marginBottom: value);
  }

  void updateMarginLeft(double value) {
    state = state.copyWith(marginLeft: value);
  }

  void updateMarginRight(double value) {
    state = state.copyWith(marginRight: value);
  }

  void updateParagraphSpacing(double spacing) {
    state = state.copyWith(paragraphSpacing: spacing);
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing);
  }

  void updateWordSpacing(double spacing) {
    state = state.copyWith(wordSpacing: spacing);
  }

  void updateFontWeightDelta(double delta) {
    state = state.copyWith(fontWeightDelta: delta);
  }

  void applyTypographyPreset({
    required ReaderFont font,
    required int fontSize,
    required double lineHeight,
    required double margin,
    required double paragraphSpacing,
    required double paragraphFirstLineIndent,
    required ReaderTextAlign textAlign,
  }) {
    state = state.copyWith(
      font: font,
      fontSize: fontSize.toDouble(),
      lineHeight: lineHeight,
      margin: margin,
      paragraphSpacing: paragraphSpacing,
      paragraphFirstLineIndent: paragraphFirstLineIndent,
      textAlign: textAlign,
    );
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
  }

  void updateAutoThemeMode(AutoThemeMode mode) {
    state = state.copyWith(autoThemeMode: mode);
  }

  void updateCustomDayHour(int hour) {
    state = state.copyWith(customDayHour: hour);
  }

  void updateCustomNightHour(int hour) {
    state = state.copyWith(customNightHour: hour);
  }

  void updateBrightness(double brightness) {
    state = state.copyWith(brightness: brightness);
  }

  void updateWarmth(double warmth) {
    state = state.copyWith(warmth: warmth);
  }

  void updateKeepScreenAwake(bool keepAwake) {
    state = state.copyWith(keepScreenAwake: keepAwake);
  }

  void updateAutoHideDelay(int seconds) {
    state = state.copyWith(autoHideDelay: seconds);
  }

  void updateProgressBarPosition(ProgressBarPosition position) {
    state = state.copyWith(progressBarPosition: position);
  }

  void updateBottomBarContent(BottomBarContent content) {
    state = state.copyWith(bottomBarContent: content);
  }

  void updateParagraphFirstLineIndent(double indent) {
    state = state.copyWith(paragraphFirstLineIndent: indent);
  }

  void updateParagraphIndentMode(ParagraphIndentMode mode) {
    state = state.copyWith(paragraphIndentMode: mode);
  }

  void updateHyphenation(bool hyphenation) {
    state = state.copyWith(hyphenation: hyphenation);
  }

  void updatePageTurnAnimation(PageTurnAnimation animation) {
    state = state.copyWith(pageTurnAnimation: animation);
  }

  void updateScrollInertia(ScrollInertia inertia) {
    state = state.copyWith(scrollInertia: inertia);
  }

  void updateTextDirection(ReaderTextDirection direction) {
    state = state.copyWith(textDirection: direction);
  }

  void updateReaderWidth(double width) {
    state = state.copyWith(readerWidth: width);
  }

  void updateVerticalSwipeBrightness(bool enabled) {
    state = state.copyWith(verticalSwipeBrightness: enabled);
  }

  void updateDoubleTapAction(DoubleTapAction action) {
    state = state.copyWith(doubleTapAction: action);
  }

  void updateLongPressAction(LongPressAction action) {
    state = state.copyWith(longPressAction: action);
  }

  void updateRestoreLastPosition(bool restore) {
    state = state.copyWith(restoreLastPosition: restore);
  }

  void updateTapZoneWidth(double width) {
    state = state.copyWith(tapZoneWidth: width.clamp(0.1, 0.5));
  }

  void updateFullScreenMode(FullScreenMode mode) {
    state = state.copyWith(fullScreenMode: mode);
  }

  void updateForcedEncoding(String? encoding) {
    state = state.copyWith(forcedEncoding: encoding);
  }

  void updateHorizontalGesture(HorizontalGesture gesture) {
    state = state.copyWith(horizontalGesture: gesture);
  }

  void updateHorizontalGestureScroll(HorizontalGestureScroll scroll) {
    state = state.copyWith(horizontalGestureScroll: scroll);
  }

  void updatePerceptionExpander(bool enabled) {
    state = state.copyWith(perceptionExpander: enabled);
  }

  void updateHideBarsOnFastScroll(bool enabled) {
    state = state.copyWith(hideBarsOnFastScroll: enabled);
  }

  void updateOrientationLock(OrientationLock lock) {
    state = state.copyWith(orientationLock: lock);
  }

  void updateBionicReading(bool value) {
    state = state.copyWith(bionicReading: value);
  }

  void updateHorizontalLimiter(bool value) {
    state = state.copyWith(horizontalLimiter: value);
  }

  void updateHorizontalLimiterHeight(double value) {
    state = state.copyWith(horizontalLimiterHeight: value);
  }

  void updateHorizontalLimiterOffset(double value) {
    state = state.copyWith(horizontalLimiterOffset: value);
  }

  void updateHorizontalLimiterDimming(double value) {
    state = state.copyWith(horizontalLimiterDimming: value);
  }

  void updateHorizontalLimiterLines(bool value) {
    state = state.copyWith(horizontalLimiterLines: value);
  }

  void updateScrollbarIndicator(bool value) {
    state = state.copyWith(scrollbarIndicator: value);
  }

  void updateShowImages(bool value) {
    state = state.copyWith(showImages: value);
  }

  void updateImageCornerRadius(double value) {
    state = state.copyWith(imageCornerRadius: value);
  }

  void updateImageAlignment(ImageAlignment value) {
    state = state.copyWith(imageAlignment: value);
  }

  void updateImageWidth(double value) {
    state = state.copyWith(imageWidth: value);
  }

  void updateImageColorEffect(ImageColorEffect value) {
    state = state.copyWith(imageColorEffect: value);
  }

  void updateActiveColorPresetId(String value) {
    state = state.copyWith(activeColorPresetId: value);
  }

  void applyProfile(ReaderSettings profile) {
    state = profile;
  }
}

@riverpod
class ReadingProgressNotifier extends _$ReadingProgressNotifier {
  @override
  ReadingProgress? build() {
    return null;
  }

  @override
  bool updateShouldNotify(ReadingProgress? previous, ReadingProgress? next) {
    if (previous == null || next == null) return previous != next;
    return previous.position.chapterIndex != next.position.chapterIndex ||
        previous.position.paragraphIndex != next.position.paragraphIndex ||
        (previous.position.localOffset - next.position.localOffset).abs() > 0.5 ||
        previous.totalPages != next.totalPages;
  }

  void updateProgress(ReadingProgress progress) {
    state = progress;
  }
}
