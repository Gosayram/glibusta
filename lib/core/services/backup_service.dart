import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

class ImportResult {
  final bool success;
  final int progressImported;
  final int bookmarksImported;
  final int notesImported;
  final int quotesImported;
  final int collectionsImported;
  final String? error;

  const ImportResult({
    required this.success,
    this.progressImported = 0,
    this.bookmarksImported = 0,
    this.notesImported = 0,
    this.quotesImported = 0,
    this.collectionsImported = 0,
    this.error,
  });
}

class BackupService {
  final AppDatabase db;
  final String appVersion;

  static const _settingsKey = 'reader_settings';
  static const _pinnedBooksKey = 'pinned_book_ids';
  static const _readingGoalMinutesKey = 'reading_goal_daily_minutes';
  static const _readingGoalEnabledKey = 'reading_goal_enabled';

  BackupService({required this.db, required this.appVersion});

  Future<String> exportData() async {
    final progress = await db.select(db.readingProgress).get();
    final bookmarks = await db.select(db.bookmarks).get();
    final notes = await db.select(db.notes).get();
    final quotes = await db.select(db.quotes).get();
    final collections = await db.select(db.collections).get();

    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    Map<String, dynamic> settings = {};
    if (settingsJson != null) {
      settings = jsonDecode(settingsJson) as Map<String, dynamic>;
    }

    final pinnedIds = prefs.getStringList(_pinnedBooksKey) ?? [];
    final goalMinutes = prefs.getInt(_readingGoalMinutesKey) ?? 30;
    final goalEnabled = prefs.getBool(_readingGoalEnabledKey) ?? false;

    final data = {
      'version': '2.0',
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'readingProgress': progress.map(_progressToMap).toList(),
      'bookmarks': bookmarks.map(_bookmarkToMap).toList(),
      'notes': notes.map(_noteToMap).toList(),
      'quotes': quotes.map(_quoteToMap).toList(),
      'collections': collections.map(_collectionToMap).toList(),
      'pinnedBooks': pinnedIds,
      'readingGoal': {
        'dailyMinutes': goalMinutes,
        'isEnabled': goalEnabled,
      },
      'settings': settings,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<ImportResult> importData(String json) async {
    try {
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      final progressList = (parsed['readingProgress'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final bookmarksList = (parsed['bookmarks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final notesList = (parsed['notes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final quotesList = (parsed['quotes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final collectionsList = (parsed['collections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final pinnedIds = (parsed['pinnedBooks'] as List?)?.cast<String>() ?? [];
      final goalMap = parsed['readingGoal'] as Map<String, dynamic>?;
      final settingsMap = parsed['settings'] as Map<String, dynamic>? ?? {};

      await db.batch((b) {
        b.deleteAll(db.readingProgress);
        b.insertAll(db.readingProgress, progressList.map(_progressFromMap));
        b.deleteAll(db.bookmarks);
        b.insertAll(db.bookmarks, bookmarksList.map(_bookmarkFromMap));
        b.deleteAll(db.notes);
        b.insertAll(db.notes, notesList.map(_noteFromMap));
        b.deleteAll(db.quotes);
        b.insertAll(db.quotes, quotesList.map(_quoteFromMap));
        b.deleteAll(db.collections);
        b.insertAll(db.collections, collectionsList.map(_collectionFromMap));
      });

      final prefs = await SharedPreferences.getInstance();
      if (settingsMap.isNotEmpty) {
        await prefs.setString(_settingsKey, jsonEncode(settingsMap));
      }
      await prefs.setStringList(_pinnedBooksKey, pinnedIds);
      if (goalMap != null) {
        await prefs.setInt(_readingGoalMinutesKey, goalMap['dailyMinutes'] as int? ?? 30);
        await prefs.setBool(_readingGoalEnabledKey, goalMap['isEnabled'] as bool? ?? false);
      }

      return ImportResult(
        success: true,
        progressImported: progressList.length,
        bookmarksImported: bookmarksList.length,
        notesImported: notesList.length,
        quotesImported: quotesList.length,
        collectionsImported: collectionsList.length,
      );
    } on FormatException catch (e) {
      return ImportResult(success: false, error: 'Invalid JSON: ${e.message}');
    } on Exception catch (e) {
      return ImportResult(success: false, error: e.toString());
    }
  }

  Future<void> clearAllData() async {
    await db.batch((b) {
      b.deleteAll(db.readingProgress);
      b.deleteAll(db.bookmarks);
      b.deleteAll(db.notes);
      b.deleteAll(db.quotes);
      b.deleteAll(db.collections);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    await prefs.remove(_pinnedBooksKey);
    await prefs.remove(_readingGoalMinutesKey);
    await prefs.remove(_readingGoalEnabledKey);
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

  Map<String, dynamic> _quoteToMap(Quote row) {
    return {
      'id': row.id,
      'bookId': row.bookId,
      'chapterIndex': row.chapterIndex,
      'paragraphIndex': row.paragraphIndex,
      'selectedText': row.selectedText,
      'beforeContext': row.beforeContext,
      'afterContext': row.afterContext,
      'note': row.note,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  QuotesCompanion _quoteFromMap(Map<String, dynamic> map) {
    return QuotesCompanion.insert(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterIndex: map['chapterIndex'] as int,
      paragraphIndex: map['paragraphIndex'] as int,
      selectedText: map['selectedText'] as String,
      beforeContext: Value(map['beforeContext'] as String?),
      afterContext: Value(map['afterContext'] as String?),
      note: Value(map['note'] as String?),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> _collectionToMap(Collection row) {
    return {
      'id': row.id,
      'name': row.name,
      'bookIds': row.bookIds,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  CollectionsCompanion _collectionFromMap(Map<String, dynamic> map) {
    return CollectionsCompanion.insert(
      id: map['id'] as String,
      name: map['name'] as String,
      bookIds: Value(map['bookIds'] as String? ?? '[]'),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
    );
  }
}
