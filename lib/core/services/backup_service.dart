import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

class ImportResult {
  final bool success;
  final int progressImported;
  final int bookmarksImported;
  final int notesImported;
  final String? error;

  const ImportResult({
    required this.success,
    this.progressImported = 0,
    this.bookmarksImported = 0,
    this.notesImported = 0,
    this.error,
  });
}

class BackupService {
  final AppDatabase db;
  final String appVersion;

  static const _settingsKey = 'reader_settings';

  BackupService({required this.db, required this.appVersion});

  Future<String> exportData() async {
    final progress = await db.select(db.readingProgress).get();
    final bookmarks = await db.select(db.bookmarks).get();
    final notes = await db.select(db.notes).get();

    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    Map<String, dynamic> settings = {};
    if (settingsJson != null) {
      settings = jsonDecode(settingsJson) as Map<String, dynamic>;
    }

    final data = {
      'version': '1.0',
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'readingProgress': progress.map(_progressToMap).toList(),
      'bookmarks': bookmarks.map(_bookmarkToMap).toList(),
      'notes': notes.map(_noteToMap).toList(),
      'settings': settings,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<ImportResult> importData(String json) async {
    try {
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      final requiredKeys = [
        'version',
        'readingProgress',
        'bookmarks',
        'notes',
        'settings',
      ];
      for (final key in requiredKeys) {
        if (!parsed.containsKey(key)) {
          return ImportResult(success: false, error: 'Missing key: $key');
        }
      }

      final progressList = (parsed['readingProgress'] as List).cast<Map<String, dynamic>>();
      final bookmarksList = (parsed['bookmarks'] as List).cast<Map<String, dynamic>>();
      final notesList = (parsed['notes'] as List).cast<Map<String, dynamic>>();
      final settingsMap = parsed['settings'] as Map<String, dynamic>;

      await db.transaction(() async {
        await db.delete(db.readingProgress).go();
        for (final row in progressList) {
          await db
              .into(db.readingProgress)
              .insert(
                _progressFromMap(row),
              );
        }

        await db.delete(db.bookmarks).go();
        for (final row in bookmarksList) {
          await db
              .into(db.bookmarks)
              .insert(
                _bookmarkFromMap(row),
              );
        }

        await db.delete(db.notes).go();
        for (final row in notesList) {
          await db
              .into(db.notes)
              .insert(
                _noteFromMap(row),
              );
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settingsMap));

      return ImportResult(
        success: true,
        progressImported: progressList.length,
        bookmarksImported: bookmarksList.length,
        notesImported: notesList.length,
      );
    } on FormatException catch (e) {
      return ImportResult(success: false, error: 'Invalid JSON: ${e.message}');
    } on Exception catch (e) {
      return ImportResult(success: false, error: e.toString());
    }
  }

  Future<void> clearAllData() async {
    await db.transaction(() async {
      await db.delete(db.readingProgress).go();
      await db.delete(db.bookmarks).go();
      await db.delete(db.notes).go();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }

  Map<String, dynamic> _progressToMap(ReadingProgressData row) {
    return {
      'bookId': row.bookId,
      'currentPosition': row.currentPosition,
      'chapterIndex': row.chapterIndex,
      'paragraphIndex': row.paragraphIndex,
      'localOffset': row.localOffset,
      'progressPercent': row.progressPercent,
      'totalPages': row.totalPages,
      'lastRead': row.lastRead.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  ReadingProgressCompanion _progressFromMap(Map<String, dynamic> map) {
    final updatedAt = map['updatedAt'] != null
        ? DateTime.parse(map['updatedAt'] as String)
        : (map['lastRead'] != null ? DateTime.parse(map['lastRead'] as String) : DateTime.now());
    return ReadingProgressCompanion.insert(
      bookId: map['bookId'] as String,
      currentPosition: Value((map['currentPosition'] as num?)?.toInt() ?? 0),
      chapterIndex: Value((map['chapterIndex'] as num?)?.toInt() ?? 0),
      paragraphIndex: Value((map['paragraphIndex'] as num?)?.toInt() ?? 0),
      localOffset: Value((map['localOffset'] as num?)?.toDouble() ?? 0.0),
      progressPercent: Value((map['progressPercent'] as num?)?.toDouble() ?? 0.0),
      totalPages: Value((map['totalPages'] as num?)?.toInt() ?? 0),
      lastRead: Value(
        map['lastRead'] != null ? DateTime.parse(map['lastRead'] as String) : DateTime.now(),
      ),
      updatedAt: Value(updatedAt),
    );
  }

  Map<String, dynamic> _bookmarkToMap(Bookmark row) {
    return {
      'id': row.id,
      'bookId': row.bookId,
      'chapterIndex': row.chapterIndex,
      'paragraphIndex': row.paragraphIndex,
      'localOffset': row.localOffset,
      'selectedText': row.selectedText,
      'note': row.note,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  BookmarksCompanion _bookmarkFromMap(Map<String, dynamic> map) {
    return BookmarksCompanion.insert(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterIndex: map['chapterIndex'] as int,
      paragraphIndex: map['paragraphIndex'] as int,
      localOffset: Value((map['localOffset'] as num?)?.toDouble() ?? 0.0),
      selectedText: Value(map['selectedText'] as String?),
      note: Value(map['note'] as String?),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> _noteToMap(Note row) {
    return {
      'id': row.id,
      'bookId': row.bookId,
      'chapterIndex': row.chapterIndex,
      'paragraphIndex': row.paragraphIndex,
      'localOffset': row.localOffset,
      'content': row.content,
      'highlightColor': row.highlightColor,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt?.toIso8601String(),
    };
  }

  NotesCompanion _noteFromMap(Map<String, dynamic> map) {
    return NotesCompanion.insert(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterIndex: map['chapterIndex'] as int,
      paragraphIndex: map['paragraphIndex'] as int,
      localOffset: Value((map['localOffset'] as num?)?.toDouble() ?? 0.0),
      content: map['content'] as String,
      highlightColor: Value(map['highlightColor'] as String? ?? '#FFEB3B'),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
      updatedAt: Value(
        map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      ),
    );
  }
}
