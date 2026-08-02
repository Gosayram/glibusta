import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reader.dart';

class ReaderTypographyPersistence {
  static String _key(String bookId) => 'reader_typo_$bookId';

  static Future<ReaderTypography> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key(bookId));
    if (json == null) return ReaderTypography.empty;
    try {
      return ReaderTypography.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on Object catch (_) {
      return ReaderTypography.empty;
    }
  }

  static Future<void> save(String bookId, ReaderTypography typography) async {
    final prefs = await SharedPreferences.getInstance();
    if (typography.isEmpty) {
      await prefs.remove(_key(bookId));
    } else {
      await prefs.setString(_key(bookId), jsonEncode(typography.toJson()));
    }
  }

  static Future<void> remove(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookId));
  }
}
