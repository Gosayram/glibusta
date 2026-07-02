import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/per_book_settings_dao.dart';
import '../domain/reader.dart';
import 'reader_settings_persistence.dart';

final perBookSettingsDaoProvider = Provider<PerBookSettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return PerBookSettingsDao(db);
});

final perBookSettingsServiceProvider = Provider<PerBookSettingsService>((ref) {
  final dao = ref.watch(perBookSettingsDaoProvider);
  return PerBookSettingsService(dao);
});

class PerBookSettingsService {
  PerBookSettingsService(this._dao);

  final PerBookSettingsDao _dao;

  Future<ReaderSettings> getEffectiveSettings(String bookId) async {
    final global = await ReaderSettingsPersistence.load();
    final perBook = await _dao.getSettings(bookId);
    if (perBook == null) return global;
    return _merge(global, perBook);
  }

  Future<void> saveBookSetting({
    required String bookId,
    required String key,
    required dynamic value,
  }) async {
    final existing = await _dao.getSettings(bookId) ?? {};
    existing[key] = value;
    await _dao.saveSettings(bookId, existing);
  }

  Future<void> resetToGlobal(String bookId) async {
    await _dao.deleteSettings(bookId);
  }

  Future<bool> hasPerBookSettings(String bookId) async {
    final settings = await _dao.getSettings(bookId);
    return settings != null && settings.isNotEmpty;
  }

  ReaderSettings _merge(ReaderSettings global, Map<String, dynamic> overrides) {
    return ReaderSettings(
      theme: _enumOverride(overrides, 'theme', ReaderTheme.values, global.theme),
      mode: _enumOverride(overrides, 'mode', ReaderMode.values, global.mode),
      twoPageEnabled: overrides['twoPageEnabled'] as bool? ?? global.twoPageEnabled,
      fontSize: (overrides['fontSize'] as num?)?.toDouble() ?? global.fontSize,
      lineHeight: (overrides['lineHeight'] as num?)?.toDouble() ?? global.lineHeight,
      margin: (overrides['margin'] as num?)?.toDouble() ?? global.margin,
      font: _enumOverride(overrides, 'font', ReaderFont.values, global.font),
      paragraphSpacing:
          (overrides['paragraphSpacing'] as num?)?.toDouble() ?? global.paragraphSpacing,
      letterSpacing: (overrides['letterSpacing'] as num?)?.toDouble() ?? global.letterSpacing,
      wordSpacing: (overrides['wordSpacing'] as num?)?.toDouble() ?? global.wordSpacing,
      textAlign: _enumOverride(
        overrides,
        'textAlign',
        ReaderTextAlign.values,
        global.textAlign,
      ),
      readerWidth: (overrides['readerWidth'] as num?)?.toDouble() ?? global.readerWidth,
      hyphenation: overrides['hyphenation'] as bool? ?? global.hyphenation,
      paragraphFirstLineIndent:
          (overrides['paragraphFirstLineIndent'] as num?)?.toDouble() ??
          global.paragraphFirstLineIndent,
      textDirection: _enumOverride(
        overrides,
        'textDirection',
        ReaderTextDirection.values,
        global.textDirection,
      ),
      pageTurnAnimation: _enumOverride(
        overrides,
        'pageTurnAnimation',
        PageTurnAnimation.values,
        global.pageTurnAnimation,
      ),
    );
  }

  T _enumOverride<T extends Enum>(
    Map<String, dynamic> overrides,
    String key,
    List<T> values,
    T defaultValue,
  ) {
    final name = overrides[key] as String?;
    if (name == null) return defaultValue;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return defaultValue;
  }
}
