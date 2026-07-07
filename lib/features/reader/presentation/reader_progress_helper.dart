import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/reader.dart';

class ReaderProgressHelper {
  ReaderProgressHelper(this._database, this._bookId);

  final AppDatabase _database;
  final String _bookId;
  final _logger = AppLogger();

  Future<ReaderPosition> loadSavedPosition(int chapterCount) async {
    try {
      final row = await (_database.select(
        _database.readingProgress,
      )..where((t) => t.bookId.equals(_bookId))).getSingleOrNull();
      if (row == null) {
        return ReaderPosition(
          bookId: _bookId,
          chapterIndex: 0,
          paragraphIndex: 0,
          updatedAt: DateTime.now(),
        );
      }
      final progressPercent = row.progressPercent <= 0 && chapterCount > 0
          ? row.chapterIndex / (chapterCount > 1 ? chapterCount - 1 : 1)
          : row.progressPercent;
      final savedBook = await (_database.select(
        _database.savedBooks,
      )..where((t) => t.id.equals(_bookId))).getSingleOrNull();
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: row.chapterIndex,
        paragraphIndex: row.paragraphIndex,
        localOffset: row.localOffset,
        progressPercent: progressPercent.clamp(0.0, 1.0),
        chapterId: row.chapterId,
        textOffset: row.textOffset,
        contentHash: savedBook?.contentHash ?? '',
        updatedAt: row.updatedAt,
      ).clamp(chapterCount: chapterCount);
    } on Object catch (e) {
      _logger.warning('Failed to load reading position for $_bookId: $e', name: 'Reader', error: e);
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: DateTime.now(),
      );
    }
  }

  void saveProgress(ReaderPosition position, int totalBlocks) {
    if (totalBlocks == 0) return;
    final pos = position.copyWith(bookId: _bookId, updatedAt: DateTime.now());
    unawaited(
      _database.bookDao
          .upsertReadingProgress(
            ReadingProgressCompanion.insert(
              bookId: _bookId,
              currentPosition: Value(pos.chapterIndex),
              chapterIndex: Value(pos.chapterIndex),
              paragraphIndex: Value(pos.paragraphIndex),
              localOffset: Value(pos.localOffset),
              progressPercent: Value(pos.progressPercent),
              chapterId: Value(pos.chapterId),
              textOffset: Value(pos.textOffset),
              totalPages: Value(totalBlocks),
              lastRead: Value(pos.updatedAt),
              updatedAt: Value(pos.updatedAt),
            ),
          )
          .then(
            (_) {},
            onError: (Object e) {
              _logger.warning(
                'Failed to save reading progress for $_bookId: $e',
                name: 'Reader',
                error: e,
              );
            },
          ),
    );
  }

  Future<void> deleteProgress() async {
    await (_database.delete(
      _database.readingProgress,
    )..where((t) => t.bookId.equals(_bookId))).go();
  }

  Future<void> deleteDownload() async {
    await (_database.delete(_database.downloads)..where((d) => d.bookId.equals(_bookId))).go();
  }
}
