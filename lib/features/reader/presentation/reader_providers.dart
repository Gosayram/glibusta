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
