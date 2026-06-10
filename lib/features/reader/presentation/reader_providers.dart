import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/reader_settings_persistence.dart';
import '../domain/reader.dart';

part 'reader_providers.g.dart';

@riverpod
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  @override
  ReaderSettings build() {
    _loadFromPrefs();
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

  void _persist() {
    unawaited(ReaderSettingsPersistence.save(state));
  }

  void updateTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _persist();
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
    _persist();
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
    _persist();
  }

  void updateFont(ReaderFont font) {
    state = state.copyWith(font: font);
    _persist();
  }

  void updateLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight);
    _persist();
  }

  void updateMargin(double margin) {
    state = state.copyWith(margin: margin);
    _persist();
  }

  void updateParagraphSpacing(double spacing) {
    state = state.copyWith(paragraphSpacing: spacing);
    _persist();
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing);
    _persist();
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
    _persist();
  }

  void updateAutoThemeMode(AutoThemeMode mode) {
    state = state.copyWith(autoThemeMode: mode);
    _persist();
  }

  void updateCustomDayHour(int hour) {
    state = state.copyWith(customDayHour: hour);
    _persist();
  }

  void updateCustomNightHour(int hour) {
    state = state.copyWith(customNightHour: hour);
    _persist();
  }

  void updateBrightness(double brightness) {
    state = state.copyWith(brightness: brightness);
    _persist();
  }

  void updateWarmth(double warmth) {
    state = state.copyWith(warmth: warmth);
    _persist();
  }

  void updateKeepScreenAwake(bool keepAwake) {
    state = state.copyWith(keepScreenAwake: keepAwake);
    _persist();
  }

  void updateAutoHideDelay(int seconds) {
    state = state.copyWith(autoHideDelay: seconds);
    _persist();
  }

  void updateProgressBarPosition(ProgressBarPosition position) {
    state = state.copyWith(progressBarPosition: position);
    _persist();
  }

  void updateBottomBarContent(BottomBarContent content) {
    state = state.copyWith(bottomBarContent: content);
    _persist();
  }

  void updateParagraphFirstLineIndent(double indent) {
    state = state.copyWith(paragraphFirstLineIndent: indent);
    _persist();
  }

  void updateHyphenation(bool hyphenation) {
    state = state.copyWith(hyphenation: hyphenation);
    _persist();
  }

  void updateTapZoneLayout(TapZoneLayout layout) {
    state = state.copyWith(tapZoneLayout: layout);
    _persist();
  }

  void updatePageTurnAnimation(PageTurnAnimation animation) {
    state = state.copyWith(pageTurnAnimation: animation);
    _persist();
  }

  void updateTextDirection(TextDirection direction) {
    state = state.copyWith(textDirection: direction);
    _persist();
  }

  void updateReaderWidth(double width) {
    state = state.copyWith(readerWidth: width);
    _persist();
  }

  void updateVerticalSwipeBrightness(bool enabled) {
    state = state.copyWith(verticalSwipeBrightness: enabled);
    _persist();
  }

  void updateDoubleTapAction(DoubleTapAction action) {
    state = state.copyWith(doubleTapAction: action);
    _persist();
  }

  void updateLongPressAction(LongPressAction action) {
    state = state.copyWith(longPressAction: action);
    _persist();
  }

  void applyProfile(ReaderSettings profile) {
    state = profile;
    _persist();
  }
}

@riverpod
class ReadingProgressNotifier extends _$ReadingProgressNotifier {
  @override
  ReadingProgress? build() {
    return null;
  }

  void updateProgress(ReadingProgress progress) {
    state = progress;
  }
}
