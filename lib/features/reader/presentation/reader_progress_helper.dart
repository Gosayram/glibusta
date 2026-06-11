import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../domain/reader.dart';

class ReaderProgressHelper {
  ReaderProgressHelper(this._database, this._bookId);

  final AppDatabase _database;
  final String _bookId;

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
      final progressPercent = row.progressPercent <= 0 && row.totalPages > 0
          ? row.chapterIndex / row.totalPages
          : row.progressPercent;
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: row.chapterIndex,
        paragraphIndex: row.paragraphIndex,
        localOffset: row.localOffset,
        progressPercent: progressPercent.clamp(0.0, 1.0),
        updatedAt: row.updatedAt,
      ).clamp(chapterCount: chapterCount);
    } on Object catch (e, st) {
      developer.log(
        'Failed to load reading position',
        name: 'ReaderProgressHelper',
        error: e,
        stackTrace: st,
      );
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: DateTime.now(),
      );
    }
  }

  void saveProgress(ReaderPosition position, int totalChapters) {
    if (totalChapters == 0) return;
    final pos = position.copyWith(bookId: _bookId, updatedAt: DateTime.now());
    unawaited(
      _database.upsertReadingProgress(
        ReadingProgressCompanion.insert(
          bookId: _bookId,
          currentPosition: Value(pos.chapterIndex),
          chapterIndex: Value(pos.chapterIndex),
          paragraphIndex: Value(pos.paragraphIndex),
          localOffset: Value(pos.localOffset),
          progressPercent: Value(pos.progressPercent),
          totalPages: Value(totalChapters),
          lastRead: Value(pos.updatedAt),
          updatedAt: Value(pos.updatedAt),
        ),
      ),
    );
  }

  Future<void> deleteProgress() async {
    await (_database.delete(_database.readingProgress)..where((t) => t.bookId.equals(_bookId))).go();
  }

  Future<void> deleteDownload() async {
    await (_database.delete(_database.downloads)..where((d) => d.bookId.equals(_bookId))).go();
  }
}
