import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'per_book_settings_dao.g.dart';

@DriftAccessor(tables: [PerBookSettings])
class PerBookSettingsDao extends DatabaseAccessor<AppDatabase> with _$PerBookSettingsDaoMixin {
  PerBookSettingsDao(super.attachedDatabase);

  Future<Map<String, dynamic>?> getSettings(String bookId) async {
    final row = await (select(
      perBookSettings,
    )..where((t) => t.bookId.equals(bookId))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.settingsJson) as Map<String, dynamic>;
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(
    String bookId,
    Map<String, dynamic> settings,
  ) async {
    await into(perBookSettings).insertOnConflictUpdate(
      PerBookSettingsCompanion.insert(
        bookId: bookId,
        settingsJson: jsonEncode(settings),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSettings(String bookId) async {
    await (delete(perBookSettings)..where((t) => t.bookId.equals(bookId))).go();
  }

  Future<List<String>> getAllBookIdsWithSettings() async {
    final rows = await select(perBookSettings).get();
    return rows.map((r) => r.bookId).toList();
  }
}
