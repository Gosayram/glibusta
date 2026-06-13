import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../epub/epub_book_adapter.dart';
import '../epub/epub_image_store.dart';
import '../epub/epub_parser.dart' as new_epub;
import 'parsers/book_parser.dart';
import 'parsers/epub_parser.dart' as legacy_epub;
import 'parsers/fb2_parser.dart';
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/txt_parser.dart';

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
  final _logger = AppLogger();

  BookOpenService(this._database);

  static const Duration _parsingTimeout = Duration(seconds: 60);

  static final Map<BookFormat, BookParser> _parsers = {
    BookFormat.epub: legacy_epub.EpubParser(),
    BookFormat.fb2: Fb2Parser(),
    BookFormat.txt: TxtBookParser(),
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

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw BookOpenFailure('Файл пуст: $filePath');
    }

    final format = detectBookFormat(filePath);
    if (format == BookFormat.unknown) {
      throw BookOpenFailure('Формат не поддерживается: ${download.format}');
    }

    if (format == BookFormat.pdf || format == BookFormat.mobi) {
      throw const BookOpenFailure('Формат не поддерживается');
    }

    return _parseInIsolate(format, filePath, bookId);
  }

  Future<NormalizedBook> _parseInIsolate(
    BookFormat bookFormat,
    String filePath, [
    String? bookId,
  ]) async {
    if (bookFormat == BookFormat.epub) {
      final effectiveBookId = bookId ?? _extractBookId(filePath);
      final bookDir = await _getBookDir(effectiveBookId);
      final imagesDir = Directory('${bookDir.path}/epub_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final imageStore = EpubImageStore(imagesDir);
      final parser = new_epub.CustomEpubParser(imageStore: imageStore);

      try {
        final epubBook = await parser
            .parse(filePath)
            .timeout(
              _parsingTimeout,
              onTimeout: () => throw TimeoutException(
                'Разбор EPUB занял слишком много времени (> ${_parsingTimeout.inSeconds}с). '
                'Попробуйте повторить.',
              ),
            );
        final adapter = EpubBookAdapter();
        final normalized = adapter.toNormalizedBook(epubBook, effectiveBookId);
        _logger.info(
          'EPUB parsed: ${epubBook.title}, ${epubBook.chapters.length} chapters, '
          '${epubBook.toc?.length ?? 0} TOC items',
          name: 'Reader',
        );
        return normalized;
      } on TimeoutException {
        rethrow;
      } on Object catch (e, st) {
        _logger.severe(
          'New EPUB parser failed, falling back to legacy: $e',
          name: 'Reader',
          error: e,
          st: st,
        );
        try {
          return await legacy_epub.EpubParser()
              .parseFile(filePath)
              .timeout(
                _parsingTimeout,
                onTimeout: () => throw TimeoutException(
                  'Разбор EPUB (legacy) занял слишком много времени. '
                  'Попробуйте повторить.',
                ),
              );
        } on TimeoutException {
          rethrow;
        }
      }
    }

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw BookOpenFailure('Файл пуст: $filePath');
      }
      final fileName = filePath.split('/').last;
      final parser = _parsers[bookFormat];
      if (parser == null) {
        throw BookOpenFailure('Формат не поддерживается: ${bookFormat.name}');
      }
      return await parser
          .parse(
            bytes,
            fileName: fileName,
          )
          .timeout(
            _parsingTimeout,
            onTimeout: () => throw TimeoutException(
              'Разбор ${bookFormat.name} занял слишком много времени.',
            ),
          );
    } on TimeoutException {
      rethrow;
    } on Object catch (e, st) {
      _logger.severe(
        'Parsing failed for $bookFormat: $e',
        name: 'Reader',
        error: e,
        st: st,
      );
      rethrow;
    }
  }

  String _extractBookId(String filePath) {
    final name = filePath.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  /// Re-parse a book with a forced encoding and update the DB metadata.
  Future<NormalizedBook> reloadWithEncoding(
    String bookId,
    String encoding,
  ) async {
    // Find the book file path from downloads
    final download = await _findDownload(bookId);
    if (download == null) {
      throw BookOpenFailure('Книга не найдена: $bookId');
    }

    final filePath = download.targetPath;
    if (filePath == null || !await File(filePath).exists()) {
      throw BookOpenFailure('Файл книги не найден: $bookId');
    }

    final format = detectBookFormat(filePath);
    if (format == BookFormat.unknown || format == BookFormat.pdf || format == BookFormat.mobi) {
      throw BookOpenFailure('Формат не поддерживается: ${format.name}');
    }

    final parser = _parsers[format];
    if (parser == null) {
      throw BookOpenFailure('Парсер не найден: ${format.name}');
    }

    // Parse with forced encoding
    final book = await parser.parseFile(filePath, forcedEncoding: encoding);

    // Update encoding metadata in DB
    await (_database.update(_database.savedBooks)..where((t) => t.id.equals(bookId))).write(
      SavedBooksCompanion(
        detectedEncoding: Value(encoding),
        encodingSource: const Value('manual'),
        userForcedEncoding: Value(encoding),
      ),
    );

    return book;
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
    final dir = await AppFileStorageImpl().cacheDir();
    return dir.path;
  }

  Future<File> _getCacheFile(String bookId) async {
    final dir = await booksCacheDir;
    return File('$dir/$bookId.json');
  }

  Future<Directory> _getBookDir(String bookId) async {
    final dir = await booksCacheDir;
    final bookDir = Directory('$dir/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return bookDir;
  }

  File _getMetadataFile(Directory bookDir) => File('${bookDir.path}/meta.json');

  File _getChapterFile(Directory bookDir, int index) => File('${bookDir.path}/ch_$index.json');

  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    try {
      final bookDir = await _getBookDir(bookId);
      final metaFile = _getMetadataFile(bookDir);
      if (!await metaFile.exists()) return null;
      final json = await metaFile.readAsString();
      return NormalizedBookMetadata.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning('Failed to read cached metadata: $e', name: 'Reader', error: e);
      return null;
    }
  }

  Future<void> _saveSplitCache(String bookId, NormalizedBook book) async {
    final bookDir = await _getBookDir(bookId);
    final metaFile = _getMetadataFile(bookDir);
    await metaFile.writeAsString(jsonEncode(book.toMetadata().toJson()));
    for (final chapter in book.chapters) {
      final chapterFile = _getChapterFile(bookDir, chapter.index);
      await chapterFile.writeAsString(jsonEncode(chapter.toJson()));
    }
  }

  Future<ReaderChapter?> loadChapter(String bookId, int index) async {
    try {
      final bookDir = await _getBookDir(bookId);
      final chapterFile = _getChapterFile(bookDir, index);
      if (!await chapterFile.exists()) return null;
      final json = await chapterFile.readAsString();
      return ReaderChapter.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning('Failed to load chapter $index for $bookId: $e', name: 'Reader', error: e);
      return null;
    }
  }

  Future<void> saveChapter(String bookId, ReaderChapter chapter) async {
    final bookDir = await _getBookDir(bookId);
    final chapterFile = _getChapterFile(bookDir, chapter.index);
    await chapterFile.writeAsString(jsonEncode(chapter.toJson()));
  }

  // Legacy monolithic cache — kept for migration fallback
  Future<NormalizedBook?> getCachedBook(String bookId) async {
    final cacheFile = await _getCacheFile(bookId);
    if (!await cacheFile.exists()) return null;
    try {
      final json = await cacheFile.readAsString();
      return NormalizedBook.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning('Failed to read cached book: $e', name: 'Reader', error: e);
      return null;
    }
  }

  Future<void> saveToCache(String bookId, NormalizedBook book) async {
    final cacheFile = await _getCacheFile(bookId);
    await cacheFile.writeAsString(jsonEncode(book.toJson()));
  }

  Future<NormalizedBook> openBookWithCache(String bookId) async {
    // Try split cache first
    final cachedMeta = await getCachedMetadata(bookId);
    if (cachedMeta != null) {
      final chapters = <ReaderChapter>[];
      for (var i = 0; i < cachedMeta.chapterCount; i++) {
        final chapter = await loadChapter(bookId, i);
        if (chapter != null) {
          chapters.add(chapter);
        }
      }
      if (chapters.length == cachedMeta.chapterCount) {
        return NormalizedBook(
          id: cachedMeta.id,
          title: cachedMeta.title,
          authors: cachedMeta.authors,
          description: cachedMeta.description,
          coverUrl: cachedMeta.coverUrl,
          chapters: chapters,
          metadata: cachedMeta.metadata,
        );
      }
    }

    // Try legacy monolithic cache
    final cached = await getCachedBook(bookId);
    if (cached != null) {
      // Migrate to split cache in background
      unawaited(_saveSplitCache(bookId, cached));
      return cached;
    }

    // Parse fresh and save as split cache
    final book = await openBook(bookId);
    await _saveSplitCache(bookId, book);
    return book;
  }
}
