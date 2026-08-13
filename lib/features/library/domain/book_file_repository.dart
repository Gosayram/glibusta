import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../reader/data/online_read_service.dart';
import '../../reader/data/parsers/format_detector.dart';

abstract interface class BookFileRepository {
  Future<File?> getFile(String bookId);
  Future<bool> exists(String bookId);
  Future<int> getFileSize(String bookId);
  Future<String?> getContentHash(String bookId);
  Future<BookFormat> getFormat(String bookId);
  Future<String?> getFilePath(String bookId);
}

final bookFileRepositoryProvider = Provider<BookFileRepository>((ref) {
  return BookFileRepositoryImpl(
    ref.watch(databaseProvider),
    onlineReadRegistry: ref.watch(onlineReadRegistryProvider),
  );
});

class BookFileRepositoryImpl implements BookFileRepository {
  BookFileRepositoryImpl(this._db, {OnlineReadRegistry? onlineReadRegistry})
    : _onlineRead = onlineReadRegistry;

  final AppDatabase _db;
  final OnlineReadRegistry? _onlineRead;

  @override
  Future<File?> getFile(String bookId) async {
    final path = await getFilePath(bookId);
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file;
  }

  @override
  Future<String?> getFilePath(String bookId) async {
    // ponytail: online-read temp override wins over the downloads table
    final online = _onlineRead?.pathFor(bookId);
    if (online != null && online.isNotEmpty && await File(online).exists()) {
      return online;
    }
    final download = await _findDownload(bookId);
    if (download?.targetPath != null && download!.targetPath!.isNotEmpty) {
      return download.targetPath;
    }
    final savedBook = await _findSavedBook(bookId);
    if (savedBook != null && savedBook.filePath.isNotEmpty) {
      return savedBook.filePath;
    }
    return null;
  }

  @override
  Future<bool> exists(String bookId) async {
    final file = await getFile(bookId);
    return file != null;
  }

  @override
  Future<int> getFileSize(String bookId) async {
    final file = await getFile(bookId);
    if (file == null) return 0;
    return file.length();
  }

  @override
  Future<String?> getContentHash(String bookId) async {
    final savedBook = await _findSavedBook(bookId);
    return savedBook?.contentHash;
  }

  @override
  Future<BookFormat> getFormat(String bookId) async {
    final download = await _findDownload(bookId);
    if (download != null) {
      final format = formatFromDbString(download.format);
      if (format != BookFormat.unknown) return format;
    }
    final path = await getFilePath(bookId);
    if (path != null) return detectBookFormat(path);
    return BookFormat.unknown;
  }

  Future<Download?> _findDownload(String bookId) async {
    final rows = await (_db.select(_db.downloads)..where((d) => d.bookId.equals(bookId))).get();
    for (final row in rows) {
      if (row.status == DownloadStatusDb.completed) {
        return row;
      }
    }
    return null;
  }

  Future<SavedBook?> _findSavedBook(String bookId) async {
    final rows = await (_db.select(_db.savedBooks)..where((book) => book.id.equals(bookId))).get();
    return rows.isNotEmpty ? rows.first : null;
  }
}
