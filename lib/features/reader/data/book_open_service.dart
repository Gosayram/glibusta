import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/failures.dart';
import '../data/parsers/book_parser.dart';
import '../data/parsers/epub_parser.dart';
import '../data/parsers/fb2_parser.dart';
import '../data/parsers/normalized_book.dart';

final bookOpenServiceProvider = Provider<BookOpenService>((ref) {
  final database = ref.watch(databaseProvider);
  return BookOpenService(database);
});

final openedBookProvider = FutureProvider.family<NormalizedBook, String>((ref, bookId) async {
  final service = ref.watch(bookOpenServiceProvider);
  return service.openBookWithCache(bookId);
});

class BookOpenService {
  final AppDatabase _database;

  BookOpenService(this._database);

  final Map<String, BookParser> _parsers = {
    'fb2': Fb2Parser(),
    'epub': EpubParser(),
  };

  Future<NormalizedBook> openBook(String bookId) async {
    final download = await _findDownload(bookId);
    if (download == null) {
      throw const BookOpenFailure('Книга не найдена в загрузках');
    }

    final filePath = download.targetPath;
    if (filePath == null || filePath.isEmpty) {
      throw const BookOpenFailure('Путь к файлу не указан');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw BookOpenFailure('Файл не найден: $filePath');
    }

    final format = download.format.toLowerCase();
    final parser = _parsers[format];
    if (parser == null) {
      throw BookOpenFailure('Формат не поддерживается: $format');
    }

    return _parseInIsolate(format, filePath);
  }

  Future<NormalizedBook> _parseInIsolate(String format, String filePath) async {
    try {
      return await Isolate.run<NormalizedBook>(() async {
        switch (format) {
          case 'epub':
            return EpubParser().parseFile(filePath);
          case 'fb2':
            return Fb2Parser().parseFile(filePath);
          default:
            throw BookOpenFailure('Формат не поддерживается: $format');
        }
      });
    } on Object catch (_) {
      final parser = _parsers[format];
      if (parser == null) {
        throw BookOpenFailure('Формат не поддерживается: $format');
      }
      return parser.parseFile(filePath);
    }
  }

  Future<Download?> _findDownload(String bookId) async {
    final rows = await (_database.select(
      _database.downloads,
    )..where((d) => d.bookId.equals(bookId))).get();
    for (final row in rows) {
      if (row.status == DownloadStatusDb.completed) {
        return row;
      }
    }
    return null;
  }

  Future<String> get booksCacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/books_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<File> _getCacheFile(String bookId) async {
    final dir = await booksCacheDir;
    return File('$dir/$bookId.json');
  }

  Future<NormalizedBook?> getCachedBook(String bookId) async {
    final cacheFile = await _getCacheFile(bookId);
    if (!await cacheFile.exists()) return null;
    try {
      final json = await cacheFile.readAsString();
      return NormalizedBook.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> saveToCache(String bookId, NormalizedBook book) async {
    final cacheFile = await _getCacheFile(bookId);
    await cacheFile.writeAsString(jsonEncode(book.toJson()));
  }

  Future<NormalizedBook> openBookWithCache(String bookId) async {
    final cached = await getCachedBook(bookId);
    if (cached != null) return cached;

    final book = await openBook(bookId);
    await saveToCache(bookId, book);
    return book;
  }
}
