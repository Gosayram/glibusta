import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';

final bookDeleteServiceProvider = Provider<BookDeleteService>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(appFileStorageProvider);
  return BookDeleteService(db, storage);
});

class BookDeleteService {
  final AppDatabase _db;
  final AppFileStorage _storage;
  final _logger = AppLogger();

  BookDeleteService(this._db, this._storage);

  Future<void> removeFromLibrary(String bookId) async {
    await _db.bookDao.softDeleteBook(bookId);
    _logger.info('Soft-deleted from library: $bookId', name: 'BookDelete');
  }

  Future<void> restoreFromTrash(String bookId) async {
    await _db.bookDao.restoreBook(bookId);
    _logger.info('Restored from trash: $bookId', name: 'BookDelete');
  }

  Future<void> purgeTrash() async {
    final deletedBooks = await _db.bookDao.getDeletedBooks();
    for (final book in deletedBooks) {
      await deleteBookCompletely(book.id);
    }
    _logger.info('Purged ${deletedBooks.length} books from trash', name: 'BookDelete');
  }

  Future<List<SavedBook>> getTrashBooks() => _db.bookDao.getDeletedBooks();

  Future<void> deleteBookCompletely(String bookId) async {
    String? targetPath;

    await _db.transaction(() async {
      final download = await (_db.select(
        _db.downloads,
      )..where((d) => d.bookId.equals(bookId))).getSingleOrNull();

      await (_db.delete(_db.downloads)..where((d) => d.bookId.equals(bookId))).go();
      await (_db.delete(_db.readingProgress)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.bookmarks)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.quotes)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.notes)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.readingSessions)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.bookCollections)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.readingTime)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.textHighlights)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.bookTags)..where((t) => t.bookId.equals(bookId))).go();
      await (_db.delete(_db.perBookSettings)..where((t) => t.bookId.equals(bookId))).go();
      await _db.bookDao.deleteBook(bookId);

      targetPath = download?.targetPath;

      _logger.info('Deleted completely: $bookId', name: 'BookDelete');
    });

    if (targetPath != null) {
      try {
        final file = File(targetPath!);
        if (await file.exists()) {
          await file.delete();
          _logger.info('Deleted file: $targetPath', name: 'BookDelete');
        }
      } on Object catch (e) {
        _logger.warning('File deletion failed: $e', name: 'BookDelete', error: e);
      }
    }

    try {
      final cacheDir = await _storage.cacheDir();
      final bookDir = Directory('${cacheDir.path}/$bookId');
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      final legacyCache = File('${cacheDir.path}/$bookId.json');
      if (await legacyCache.exists()) {
        await legacyCache.delete();
      }
      final coversDir = await _storage.coversDir();
      final coverFile = File('${coversDir.path}/$bookId.jpg');
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    } on Object catch (e) {
      _logger.warning('Cache cleanup failed for $bookId: $e', name: 'BookDelete', error: e);
    }
  }
}
