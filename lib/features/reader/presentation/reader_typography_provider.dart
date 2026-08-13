import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/reader_typography_persistence.dart';
import '../domain/reader.dart';
import 'reader_providers.dart';

part 'reader_typography_provider.g.dart';

@riverpod
class ReaderTypographyNotifier extends _$ReaderTypographyNotifier {
  bool _isLoading = false;

  @override
  ReaderTypography build(String bookId) {
    unawaited(_load());
    return ReaderTypography.empty;
  }

  Future<void> _load() async {
    _isLoading = true;
    state = await ReaderTypographyPersistence.load(bookId);
    _isLoading = false;
  }

  Future<void> update(ReaderTypography typography) async {
    if (_isLoading) return;
    state = typography;
    await ReaderTypographyPersistence.save(bookId, typography);
    _applyToGlobalSettings();
  }

  Future<void> reset() async {
    state = ReaderTypography.empty;
    await ReaderTypographyPersistence.remove(bookId);
    _applyToGlobalSettings();
  }

  void _applyToGlobalSettings() {
    final global = ref.read(readerSettingsProvider);
    ref
        .read(readerSettingsProvider.notifier)
        .applyProfile(
          _mergeWithGlobal(global, state),
        );
  }

  static ReaderSettings _mergeWithGlobal(ReaderSettings global, ReaderTypography typo) {
    if (typo.isEmpty) return global;
    return global.copyWith(
      fontSize: typo.fontSize ?? global.fontSize,
      lineHeight: typo.lineHeight ?? global.lineHeight,
      margin: typo.marginHorizontal ?? global.margin,
      font: typo.fontFamily != null
          ? ReaderFont.values.firstWhere(
              (f) => f.name == typo.fontFamily,
              orElse: () => global.font,
            )
          : global.font,
      theme: typo.darkMode != null
          ? (typo.darkMode! ? ReaderTheme.dark : ReaderTheme.light)
          : global.theme,
    );
  }
}
