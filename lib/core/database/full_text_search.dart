import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import 'app_database.dart';

final fullTextSearchProvider = Provider<FullTextSearchService>((ref) {
  final db = ref.watch(databaseProvider);
  return FullTextSearchService(db);
});

/// Full-text search service using SQLite FTS5.
///
/// Provides indexing and search across all imported book content.
/// The FTS5 virtual table is created lazily on first use.
class FullTextSearchService {
  FullTextSearchService(this._db);

  final AppDatabase _db;
  final _logger = AppLogger();
  bool _initialized = false;

  /// Ensure the FTS5 virtual table exists.
  Future<void> _ensureFtsTable() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS books_fts USING fts5(
        bookId,
        chapterIndex UNINDEXED,
        title,
        content,
        tokenize='unicode61 remove_diacritics 2'
      )
    ''');
    _initialized = true;
  }

  /// Index a single chapter's content for a book.
  Future<void> indexChapter({
    required String bookId,
    required int chapterIndex,
    required String title,
    required String content,
  }) async {
    await _ensureFtsTable();
    // ponytail: wrap in transaction so concurrent search never sees a gap.
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM books_fts WHERE bookId = ? AND chapterIndex = ?',
        [bookId, chapterIndex],
      );
      await _db.customStatement(
        'INSERT INTO books_fts(bookId, chapterIndex, title, content) VALUES(?, ?, ?, ?)',
        [bookId, chapterIndex, title, content],
      );
    });
  }

  /// Index all chapters for a book at once.
  Future<void> indexBook({
    required String bookId,
    required List<BookChapterContent> chapters,
  }) async {
    await _ensureFtsTable();
    // ponytail: single transaction + batch — atomic and 1 fsync instead of N+1.
    await _db.transaction(() async {
      await _db.customStatement(
        'DELETE FROM books_fts WHERE bookId = ?',
        [bookId],
      );
      await _db.batch((b) {
        for (final chapter in chapters) {
          b.customStatement(
            'INSERT INTO books_fts(bookId, chapterIndex, title, content) VALUES(?, ?, ?, ?)',
            [bookId, chapter.chapterIndex, chapter.title, chapter.content],
          );
        }
      });
    });
    _logger.info(
      'Indexed ${chapters.length} chapters for book $bookId',
      name: 'FTS',
    );
  }

  /// Remove all indexed content for a book.
  Future<void> removeBook(String bookId) async {
    await _ensureFtsTable();
    await _db.customStatement(
      'DELETE FROM books_fts WHERE bookId = ?',
      [bookId],
    );
  }

  /// Search across all indexed book content.
  ///
  /// Returns results ranked by BM25 relevance.
  Future<List<FtsSearchResult>> search(
    String query, {
    int limit = 50,
  }) async {
    await _ensureFtsTable();
    if (query.trim().isEmpty) return const [];

    // Treat user input as a literal FTS5 phrase rather than an FTS expression.
    final sanitized = '"${query.replaceAll('"', '""')}"';

    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT
          bookId,
          chapterIndex,
          title,
          snippet(books_fts, 3, '<b>', '</b>', '...', 32) as snippet,
          bm25(books_fts) as rank
        FROM books_fts
        WHERE books_fts MATCH ?
        ORDER BY rank
        LIMIT ?
        ''',
            variables: [Variable.withString(sanitized), Variable.withInt(limit)],
          )
          .get();

      return rows.map((row) {
        return FtsSearchResult(
          bookId: row.read<String>('bookId'),
          chapterIndex: row.read<int>('chapterIndex'),
          chapterTitle: row.read<String>('title'),
          snippet: row.read<String>('snippet'),
          rank: row.read<double>('rank'),
        );
      }).toList();
    } on Object catch (e) {
      _logger.warning('FTS search failed for "$query": $e', name: 'FTS', error: e);
      return const [];
    }
  }

  /// Get the total number of indexed entries.
  Future<int> get indexedEntryCount async {
    await _ensureFtsTable();
    final result = await _db
        .customSelect(
          'SELECT COUNT(*) as count FROM books_fts',
        )
        .get();
    return result.first.read<int>('count');
  }

  /// Get the number of indexed books.
  Future<int> get indexedBookCount async {
    await _ensureFtsTable();
    final result = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT bookId) as count FROM books_fts',
        )
        .get();
    return result.first.read<int>('count');
  }

  /// Drop the FTS table (for testing or full re-index).
  Future<void> dropFtsTable() async {
    await _db.customStatement('DROP TABLE IF EXISTS books_fts');
    _initialized = false;
  }
}

/// Content of a single chapter for FTS indexing.
class BookChapterContent {
  const BookChapterContent({
    required this.chapterIndex,
    required this.title,
    required this.content,
  });

  final int chapterIndex;
  final String title;
  final String content;
}

/// A single FTS search result.
class FtsSearchResult {
  const FtsSearchResult({
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
    required this.rank,
  });

  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String snippet;
  final double rank;
}
