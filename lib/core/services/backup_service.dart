import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';

class ImportResult {
  final bool success;
  final int progressImported;
  final int bookmarksImported;
  final int notesImported;
  final int quotesImported;
  final int collectionsImported;
  final int highlightsImported;
  final String? error;

  const ImportResult({
    required this.success,
    this.progressImported = 0,
    this.bookmarksImported = 0,
    this.notesImported = 0,
    this.quotesImported = 0,
    this.collectionsImported = 0,
    this.highlightsImported = 0,
    this.error,
  });
}

class BackupService {
  final AppDatabase db;
  final String appVersion;
  final _logger = AppLogger();

  static const _settingsKey = 'reader_settings';
  static const _pinnedBooksKey = 'pinned_book_ids';
  static const _readingGoalMinutesKey = 'reading_goal_daily_minutes';
  static const _readingGoalEnabledKey = 'reading_goal_enabled';

  BackupService({required this.db, required this.appVersion});

  Future<String> exportData() async {
    _logger.info('Starting export', name: 'Backup');
    try {
      final progress = await db.select(db.readingProgress).get();
      final bookmarks = await db.select(db.bookmarks).get();
      final notes = await db.select(db.notes).get();
      final quotes = await db.select(db.quotes).get();
      final collections = await db.select(db.collections).get();
      final highlights = await db.select(db.textHighlights).get();

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
        'textHighlights': highlights.map(_highlightToMap).toList(),
        'pinnedBooks': pinnedIds,
        'readingGoal': {
          'dailyMinutes': goalMinutes,
          'isEnabled': goalEnabled,
        },
        'settings': settings,
      };

      _logger.info(
        'Export complete: ${progress.length} progress, ${bookmarks.length} bookmarks, ${notes.length} notes, ${quotes.length} quotes, ${collections.length} collections, ${highlights.length} highlights',
        name: 'Backup',
      );
      return const JsonEncoder.withIndent('  ').convert(data);
    } on Exception catch (e) {
      _logger.severe('Export failed: $e', name: 'Backup');
      rethrow;
    }
  }

  Future<ImportResult> importData(String json) async {
    _logger.info('Starting import (size: ${json.length})', name: 'Backup');
    try {
      final parsed = jsonDecode(json) as Map<String, dynamic>;

      final progressList = (parsed['readingProgress'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final bookmarksList = (parsed['bookmarks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final notesList = (parsed['notes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final quotesList = (parsed['quotes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final collectionsList = (parsed['collections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final highlightsList = (parsed['textHighlights'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
        b.deleteAll(db.textHighlights);
        b.insertAll(db.textHighlights, highlightsList.map(_highlightFromMap));

        // ponytail: bookCollections junction table is not exported, rebuild
        // from collections.bookIds so getBooksInCollection/getCollectionsForBook
        // return correct results after import.
        b.deleteAll(db.bookCollections);
        for (final collectionMap in collectionsList) {
          final collectionId = collectionMap['id'] as String;
          final bookIds = collectionMap['bookIds'] is String
              ? _safeDecodeBookIds(collectionMap['bookIds'] as String)
              : (collectionMap['bookIds'] as List<dynamic>?)?.cast<String>() ??
                  <String>[];
          for (final bookId in bookIds) {
            b.insert(
              db.bookCollections,
              BookCollectionsCompanion.insert(
                bookId: bookId,
                collectionId: collectionId,
              ),
            );
          }
        }
      });

      final prefs = await SharedPreferences.getInstance();
      if (settingsMap.isNotEmpty) {
        await prefs.setString(_settingsKey, jsonEncode(settingsMap));
      }
      if (parsed.containsKey('pinnedBooks')) {
        await prefs.setStringList(_pinnedBooksKey, pinnedIds);
      }
      if (goalMap != null) {
        await prefs.setInt(_readingGoalMinutesKey, (goalMap['dailyMinutes'] as num?)?.toInt() ?? 30);
        await prefs.setBool(_readingGoalEnabledKey, goalMap['isEnabled'] as bool? ?? false);
      }

      _logger.info(
        'Import complete: ${progressList.length} progress, ${bookmarksList.length} bookmarks, ${notesList.length} notes, ${quotesList.length} quotes, ${collectionsList.length} collections, ${highlightsList.length} highlights',
        name: 'Backup',
      );
      return ImportResult(
        success: true,
        progressImported: progressList.length,
        bookmarksImported: bookmarksList.length,
        notesImported: notesList.length,
        quotesImported: quotesList.length,
        collectionsImported: collectionsList.length,
        highlightsImported: highlightsList.length,
      );
    } on FormatException catch (e) {
      _logger.warning('Import failed: invalid JSON - ${e.message}', name: 'Backup');
      return ImportResult(success: false, error: 'Invalid JSON: ${e.message}');
    } on Exception catch (e) {
      _logger.warning('Import failed: $e', name: 'Backup');
      return ImportResult(success: false, error: e.toString());
    }
  }

  Future<void> clearAllData() async {
    _logger.warning('Clearing all user data', name: 'Backup');
    await db.batch((b) {
      b.deleteAll(db.readingProgress);
      b.deleteAll(db.bookmarks);
      b.deleteAll(db.notes);
      b.deleteAll(db.quotes);
      b.deleteAll(db.textHighlights);
      b.deleteAll(db.readingSessions);
      b.deleteAll(db.readingTime);
      b.deleteAll(db.perBookSettings);
      b.deleteAll(db.searchHistory);
      b.deleteAll(db.downloads);
      b.deleteAll(db.bookCollections);
      b.deleteAll(db.bookTags);
      b.deleteAll(db.bookSeries);
      b.deleteAll(db.collections);
      b.deleteAll(db.tags);
      b.deleteAll(db.series);
      b.deleteAll(db.authors);
      b.deleteAll(db.genres);
      b.deleteAll(db.savedBooks);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    await prefs.remove(_pinnedBooksKey);
    await prefs.remove(_readingGoalMinutesKey);
    await prefs.remove(_readingGoalEnabledKey);
    _logger.info('All data cleared', name: 'Backup');
  }

  Map<String, dynamic> _progressToMap(ReadingProgressData row) {
    return {
      'bookId': row.bookId,
      'currentPosition': row.currentPosition,
      'chapterIndex': row.chapterIndex,
      'paragraphIndex': row.paragraphIndex,
      'localOffset': row.localOffset,
      'progressPercent': row.progressPercent,
      'chapterId': row.chapterId,
      'textOffset': row.textOffset,
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
      chapterId: Value(map['chapterId'] as String? ?? ''),
      textOffset: Value((map['textOffset'] as num?)?.toInt() ?? 0),
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
      'highlightStyle': row.highlightStyle,
      'highlightColor': row.highlightColor,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  BookmarksCompanion _bookmarkFromMap(Map<String, dynamic> map) {
    return BookmarksCompanion.insert(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      paragraphIndex: (map['paragraphIndex'] as num?)?.toInt() ?? 0,
      localOffset: Value((map['localOffset'] as num?)?.toDouble() ?? 0.0),
      selectedText: Value(map['selectedText'] as String?),
      note: Value(map['note'] as String?),
      highlightStyle: Value(map['highlightStyle'] as String?),
      highlightColor: Value(map['highlightColor'] as String?),
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
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      paragraphIndex: (map['paragraphIndex'] as num?)?.toInt() ?? 0,
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
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      paragraphIndex: (map['paragraphIndex'] as num?)?.toInt() ?? 0,
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
      'description': row.description,
      'bookIds': row.bookIds,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  CollectionsCompanion _collectionFromMap(Map<String, dynamic> map) {
    return CollectionsCompanion.insert(
      id: map['id'] as String,
      name: map['name'] as String,
      description: Value(map['description'] as String?),
      bookIds: Value(
        map['bookIds'] is String
            ? _safeDecodeBookIds(map['bookIds'] as String)
            : (map['bookIds'] as List<dynamic>?)?.cast<String>() ?? [],
      ),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> _highlightToMap(TextHighlight row) {
    return {
      'id': row.id,
      'bookId': row.bookId,
      'chapterId': row.chapterId,
      'chapterIndex': row.chapterIndex,
      'blockIndex': row.blockIndex,
      'startOffset': row.startOffset,
      'endOffset': row.endOffset,
      'selectedText': row.selectedText,
      'color': row.color,
      'decoration': row.decoration,
      'noteText': row.noteText,
      'isOrphaned': row.isOrphaned,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt?.toIso8601String(),
    };
  }

  TextHighlightsCompanion _highlightFromMap(Map<String, dynamic> map) {
    return TextHighlightsCompanion.insert(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      chapterId: map['chapterId'] as String,
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
      blockIndex: (map['blockIndex'] as num?)?.toInt() ?? 0,
      startOffset: (map['startOffset'] as num?)?.toInt() ?? 0,
      endOffset: (map['endOffset'] as num?)?.toInt() ?? 0,
      selectedText: map['selectedText'] as String,
      color: Value(map['color'] as String? ?? 'yellow'),
      decoration: Value(map['decoration'] as String? ?? 'none'),
      noteText: Value(map['noteText'] as String?),
      isOrphaned: Value(map['isOrphaned'] as bool? ?? false),
      createdAt: Value(
        map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      ),
      updatedAt: Value(
        map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      ),
    );
  }

  static List<String> _safeDecodeBookIds(String raw) {
    try {
      return List<String>.from(jsonDecode(raw) as List<dynamic>);
    } on Object catch (_) {
      return [];
    }
  }
}
