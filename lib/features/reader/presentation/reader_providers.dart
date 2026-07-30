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
  bool _isApplyingTransientProfile = false;

  @override
  ReaderSettings build() {
    _loadFromPrefs();
    listenSelf((prev, next) {
      if (prev != next) {
        if (_isApplyingTransientProfile) return;
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

  void updateUiTheme(ReaderTheme? uiTheme) {
    state = state.copyWith(uiTheme: uiTheme);
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  void updateNoteFontSize(double? fontSize) {
    state = state.copyWith(noteFontSize: fontSize);
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
  }

  void updateTwoPageEnabled(bool enabled) {
    state = state.copyWith(twoPageEnabled: enabled);
  }

  /// Updates the current book's layout profile without overwriting the
  /// reader-wide default in SharedPreferences.
  void applyPerBookTwoPageEnabled(bool enabled) {
    _isApplyingTransientProfile = true;
    state = state.copyWith(twoPageEnabled: enabled);
    _isApplyingTransientProfile = false;
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

  void updateMarginAsPercent(bool enabled) {
    state = state.copyWith(marginAsPercent: enabled);
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
    ReaderTheme? theme,
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
    if (theme != null) {
      state = state.copyWith(theme: theme);
    }
  }

  /// Restores only the settings that affect text readability.
  ///
  /// Theme, reading mode, gestures, and language-specific hyphenation remain
  /// untouched so this is safe to use as a quick recovery from an unsuitable
  /// font or spacing configuration.
  void resetTypography() {
    state = state.copyWith(
      fontSize: 18,
      noteFontSize: null,
      lineHeight: 1.6,
      margin: 20,
      marginTop: 20,
      marginBottom: 20,
      marginLeft: 20,
      marginRight: 20,
      separateMargins: false,
      font: ReaderFont.literata,
      paragraphSpacing: 20,
      letterSpacing: 0,
      wordSpacing: 0,
      fontWeightDelta: 0,
      textAlign: ReaderTextAlign.justify,
      paragraphFirstLineIndent: 16,
      paragraphIndentMode: ParagraphIndentMode.firstLine,
      oldStyleFigures: false,
      smallCaps: false,
    );
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
  }

  void updateAutoThemeMode(AutoThemeMode mode) {
    state = state.copyWith(autoThemeMode: mode);
  }

  void updateNightTheme(ReaderTheme theme) {
    state = state.copyWith(nightTheme: theme);
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

  void updateOldStyleFigures(bool value) {
    state = state.copyWith(oldStyleFigures: value);
  }

  void updateSmallCaps(bool value) {
    state = state.copyWith(smallCaps: value);
  }

  void updateRsvpWpm(int value) {
    state = state.copyWith(rsvpWpm: value.clamp(100, 1000));
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

  void updatePageTurnHaptic(bool enabled) {
    state = state.copyWith(pageTurnHaptic: enabled);
  }

  void updateTwoFingerChapterNavigation(bool enabled) {
    state = state.copyWith(twoFingerChapterNavigation: enabled);
  }

  void updateDoubleTapAction(DoubleTapAction action) {
    state = state.copyWith(doubleTapAction: action);
  }

  void updateLongPressAction(LongPressAction action) {
    state = state.copyWith(longPressAction: action);
  }

  void updateCornerTapAction(ReaderCorner corner, CornerTapAction action) {
    state = switch (corner) {
      ReaderCorner.topLeft => state.copyWith(topLeftCornerTapAction: action),
      ReaderCorner.topRight => state.copyWith(topRightCornerTapAction: action),
      ReaderCorner.bottomLeft => state.copyWith(bottomLeftCornerTapAction: action),
      ReaderCorner.bottomRight => state.copyWith(bottomRightCornerTapAction: action),
    };
  }

  void resetCornerTapActions() {
    state = state.copyWith(
      topLeftCornerTapAction: CornerTapAction.inherit,
      topRightCornerTapAction: CornerTapAction.inherit,
      bottomLeftCornerTapAction: CornerTapAction.inherit,
      bottomRightCornerTapAction: CornerTapAction.inherit,
    );
  }

  void updateCornerLongPressAction(ReaderCorner corner, CornerLongPressAction action) {
    state = switch (corner) {
      ReaderCorner.topLeft => state.copyWith(topLeftCornerLongPressAction: action),
      ReaderCorner.topRight => state.copyWith(topRightCornerLongPressAction: action),
      ReaderCorner.bottomLeft => state.copyWith(bottomLeftCornerLongPressAction: action),
      ReaderCorner.bottomRight => state.copyWith(bottomRightCornerLongPressAction: action),
    };
  }

  void resetCornerLongPressActions() {
    state = state.copyWith(
      topLeftCornerLongPressAction: CornerLongPressAction.inherit,
      topRightCornerLongPressAction: CornerLongPressAction.inherit,
      bottomLeftCornerLongPressAction: CornerLongPressAction.inherit,
      bottomRightCornerLongPressAction: CornerLongPressAction.inherit,
    );
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

  void updateCustomCss(String css) {
    state = state.copyWith(customCss: css);
  }

  void updateIgnoreBookAlignment(bool value) {
    state = state.copyWith(ignoreBookAlignment: value);
  }

  void updateIgnoreBookIndent(bool value) {
    state = state.copyWith(ignoreBookIndent: value);
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

  void updateEink(bool value) {
    state = state.copyWith(eink: value);
    if (value) {
      state = state.copyWith(
        theme: ReaderTheme.light,
        autoThemeMode: AutoThemeMode.off,
        hideBarsOnFastScroll: false,
        pageTurnAnimation: PageTurnAnimation.none,
      );
    }
  }

  void applyProfile(ReaderSettings profile) {
    // A per-book profile is the effective configuration for the current
    // session. It must not replace the reader's global defaults in
    // SharedPreferences.
    _isApplyingTransientProfile = true;
    state = profile;
    _isApplyingTransientProfile = false;
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
