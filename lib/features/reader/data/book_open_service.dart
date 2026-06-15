import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/encoding/encoding_detection.dart';
import '../../../core/errors/failures.dart';
import '../../../core/formats/book_file_size_policy.dart';
import '../../../core/formats/rtf_format_handler.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../epub/epub_book_adapter.dart';
import '../epub/epub_image_store.dart';
import '../epub/epub_parser.dart' as new_epub;
import 'parsers/epub_parser.dart' as legacy_epub;
import 'parsers/fb2_parser.dart';
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/parser_registry.dart';
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
  static const int _splitCacheVersion = 1;
  static const int _parserCacheVersion = 1;

  static final _registry = BookParserRegistry.defaultInstance;

  static Future<NormalizedBook> _parseEpubInWorker(
    ({String filePath, String imagesDirPath, String bookId}) args,
  ) async {
    final imageStore = EpubImageStore(Directory(args.imagesDirPath));
    final parser = new_epub.CustomEpubParser(imageStore: imageStore);
    final epubBook = await parser.parse(args.filePath);
    return EpubBookAdapter().toNormalizedBook(epubBook, args.bookId);
  }

  static Future<NormalizedBook> _parseRtfInWorker(({String filePath, String bookId}) args) async {
    final document = await RtfFormatHandler().prepare(args.filePath);
    return document.toNormalizedBook(args.bookId);
  }

  static Future<NormalizedBook> _parseTextBasedInWorker(
    ({BookFormat format, List<int> bytes, String fileName}) args,
  ) async {
    final typedBytes = args.bytes is Uint8List
        ? args.bytes as Uint8List
        : Uint8List.fromList(args.bytes);
    final detector = BookEncodingDetector();
    final detectionResult = await detector.detect(typedBytes, fileName: args.fileName);
    final detectedText = detectionResult.text;
    return switch (args.format) {
      BookFormat.fb2 => parseFb2FromText(detectedText, fileName: args.fileName),
      BookFormat.txt => parseTxtFromText(detectedText, fileName: args.fileName),
      _ => throw const UnsupportedFormatFailure(),
    };
  }

  Future<NormalizedBook> openBook(String bookId) async {
    final cid = 'open-$bookId-${DateTime.now().millisecondsSinceEpoch}';
    _logger.info('Opening book', name: 'Reader', cid: cid);
    final download = await _findDownload(bookId);
    if (download == null) {
      throw const BookMissingFailure('Книга не найдена в загрузках');
    }

    final filePath = download.targetPath;
    if (filePath == null || filePath.isEmpty) {
      throw const BookMissingFailure('Путь к файлу не указан');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const BookMissingFailure('Файл книги не найден');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw const CacheCorruptedFailure('Файл пуст');
    }

    final format = detectBookFormat(filePath);
    if (format == BookFormat.unknown) {
      throw UnsupportedFormatFailure(
        'Формат не поддерживается: ${formatFromDbString(download.format).name}',
      );
    }
    if (isBookFileTooLarge(format, fileSize)) {
      throw UnsupportedFormatFailure(bookFileTooLargeMessage(format, fileSize));
    }

    if (format == BookFormat.pdf || format == BookFormat.djvu) {
      throw const UnsupportedFormatFailure('Формат не поддерживается');
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

      try {
        final normalized =
            await Isolate.run(
              () => _parseEpubInWorker((
                filePath: filePath,
                imagesDirPath: imagesDir.path,
                bookId: effectiveBookId,
              )),
            ).timeout(
              _parsingTimeout,
              onTimeout: () => throw TimeoutException(
                'Разбор EPUB занял слишком много времени (> ${_parsingTimeout.inSeconds}с). '
                'Попробуйте повторить.',
              ),
            );
        _logger.info(
          'EPUB parsed: ${normalized.title}, ${normalized.chapters.length} chapters',
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
        } on Object catch (e, st) {
          _logger.severe(
            'Legacy EPUB parser also failed: $e',
            name: 'Reader',
            error: e,
            st: st,
          );
          rethrow;
        }
      }
    }

    if (bookFormat == BookFormat.rtf) {
      final effectiveBookId = bookId ?? _extractBookId(filePath);
      return Isolate.run(
        () => _parseRtfInWorker((filePath: filePath, bookId: effectiveBookId)),
      ).timeout(
        _parsingTimeout,
        onTimeout: () => throw TimeoutException(
          'Разбор RTF занял слишком много времени.',
        ),
      );
    }

    if (bookFormat == BookFormat.mobi ||
        bookFormat == BookFormat.azw3 ||
        bookFormat == BookFormat.prc) {
      final parser = _registry.parserForFormat(bookFormat);
      if (parser == null) {
        throw UnsupportedFormatFailure('Формат не поддерживается: ${bookFormat.name}');
      }
      return parser
          .parseFile(filePath)
          .timeout(
            _parsingTimeout,
            onTimeout: () => throw TimeoutException(
              'Разбор ${bookFormat.name.toUpperCase()} занял слишком много времени.',
            ),
          );
    }

    try {
      final file = File(filePath);
      final fileSize = await file.length();
      if (isBookFileTooLarge(bookFormat, fileSize)) {
        throw UnsupportedFormatFailure(bookFileTooLargeMessage(bookFormat, fileSize));
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const CacheCorruptedFailure('Файл пуст');
      }
      final fileName = filePath.split('/').last;

      if (bookFormat == BookFormat.epub) {
        final parser = _registry.parserForFormat(bookFormat);
        if (parser == null) {
          throw UnsupportedFormatFailure('Формат не поддерживается: ${bookFormat.name}');
        }
        return await parser
            .parse(bytes, fileName: fileName)
            .timeout(
              _parsingTimeout,
              onTimeout: () => throw TimeoutException(
                'Разбор ${bookFormat.name} занял слишком много времени.',
              ),
            );
      }

      return await Isolate.run(
        () => _parseTextBasedInWorker(
          (format: bookFormat, bytes: bytes, fileName: fileName),
        ),
      ).timeout(
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
      throw BookMissingFailure('Книга не найдена: $bookId');
    }

    final filePath = download.targetPath;
    if (filePath == null || !await File(filePath).exists()) {
      throw BookMissingFailure('Файл книги не найден: $bookId');
    }

    final format = detectBookFormat(filePath);
    if (format == BookFormat.unknown ||
        format == BookFormat.pdf ||
        format == BookFormat.mobi ||
        format == BookFormat.azw3 ||
        format == BookFormat.prc ||
        format == BookFormat.djvu) {
      throw UnsupportedFormatFailure('Формат не поддерживается: ${format.name}');
    }

    final parser = _registry.parserForFormat(format);
    if (parser == null) {
      throw UnsupportedFormatFailure('Парсер не найден: ${format.name}');
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

  Future<SavedBook?> _findSavedBook(String bookId) async {
    final rows = await (_database.select(
      _database.savedBooks,
    )..where((book) => book.id.equals(bookId))).get();
    return rows.isNotEmpty ? rows.first : null;
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

  Future<Directory> _getExistingBookDir(String bookId) async {
    final dir = await booksCacheDir;
    return Directory('$dir/$bookId');
  }

  File _getMetadataFile(Directory bookDir) => File('${bookDir.path}/meta.json');

  File _getManifestFile(Directory bookDir) => File('${bookDir.path}/manifest.json');

  File _getChapterFile(Directory bookDir, int index) => File('${bookDir.path}/ch_$index.json');

  Future<void> _writeJsonAtomically(File target, Object? value) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    try {
      final bookDir = await _getExistingBookDir(bookId);
      if (!await bookDir.exists()) return null;
      final metaFile = _getMetadataFile(bookDir);
      if (!await metaFile.exists()) return null;
      final json = await metaFile.readAsString();
      return NormalizedBookMetadata.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning('Failed to read cached metadata: $e', name: 'Reader', error: e);
      return null;
    }
  }

  Future<bool> _isSplitCacheComplete(Directory bookDir, NormalizedBookMetadata meta) async {
    final manifestFile = _getManifestFile(bookDir);
    if (await manifestFile.exists()) {
      try {
        final json = await manifestFile.readAsString();
        final manifest = jsonDecode(json) as Map<String, dynamic>;
        final version = manifest['version'] as int?;
        final parserVersion = manifest['parserVersion'] as int?;
        final cachedFormat = manifest['format'] as String?;
        final cachedFileSize = manifest['fileSize'] as int?;
        final cachedFileMtime = manifest['fileMtime'] as int?;
        final cachedContentHash = manifest['contentHash'] as String?;
        final chapterCount = manifest['chapterCount'] as int?;
        final chapters = (manifest['chapters'] as List<dynamic>?)?.cast<int>() ?? const <int>[];
        final source = await _cacheSourceFingerprint(meta.id);
        if (source == null) {
          return false;
        }
        if (version != _splitCacheVersion ||
            parserVersion != _parserCacheVersion ||
            cachedFormat != source.format ||
            cachedFileSize != source.fileSize ||
            cachedFileMtime != source.fileMtime ||
            cachedContentHash != source.contentHash ||
            chapterCount != meta.chapterCount ||
            chapters.length != meta.chapterCount) {
          return false;
        }
        for (final index in chapters) {
          if (!await _getChapterFile(bookDir, index).exists()) return false;
        }
        return true;
      } on Object catch (e) {
        _logger.warning('Failed to validate split cache manifest: $e', name: 'Reader', error: e);
        return false;
      }
    }

    return false;
  }

  Future<void> _saveSplitCache(String bookId, NormalizedBook book) async {
    final bookDir = await _getBookDir(bookId);
    final metaFile = _getMetadataFile(bookDir);
    final source = await _cacheSourceFingerprint(bookId);
    await _writeJsonAtomically(metaFile, book.toMetadata().toJson());
    for (final chapter in book.chapters) {
      final chapterFile = _getChapterFile(bookDir, chapter.index);
      await _writeJsonAtomically(chapterFile, chapter.toJson());
    }
    await _writeJsonAtomically(
      _getManifestFile(bookDir),
      {
        'version': _splitCacheVersion,
        'parserVersion': _parserCacheVersion,
        'bookId': bookId,
        'format': source?.format,
        'fileSize': source?.fileSize,
        'fileMtime': source?.fileMtime,
        'contentHash': source?.contentHash,
        'chapterCount': book.chapters.length,
        'chapters': book.chapters.map((chapter) => chapter.index).toList(),
      },
    );
  }

  Future<_CacheSourceFingerprint?> _cacheSourceFingerprint(String bookId) async {
    final download = await _findDownload(bookId);
    final filePath = download?.targetPath;
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final stat = await file.stat();
    final savedBook = await _findSavedBook(bookId);
    return _CacheSourceFingerprint(
      format: detectBookFormat(filePath).name,
      fileSize: stat.size,
      fileMtime: stat.modified.millisecondsSinceEpoch,
      contentHash: savedBook?.contentHash,
    );
  }

  Future<ReaderChapter?> loadChapter(String bookId, int index) async {
    try {
      final bookDir = await _getExistingBookDir(bookId);
      if (!await bookDir.exists()) return null;
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
    await _writeJsonAtomically(chapterFile, chapter.toJson());
  }

  Future<void> invalidateBookCache(String bookId) async {
    final bookDir = await _getExistingBookDir(bookId);
    if (!await bookDir.exists()) return;
    try {
      await bookDir.delete(recursive: true);
      _logger.info('Reader cache invalidated for $bookId', name: 'Reader');
    } on Object catch (e) {
      _logger.warning(
        'Failed to invalidate reader cache for $bookId: $e',
        name: 'Reader',
        error: e,
      );
    }
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

  Future<void> _migrateLegacyCache(String bookId, NormalizedBook book) async {
    try {
      await _saveSplitCache(bookId, book);
    } on Object catch (e, st) {
      _logger.warning(
        'Legacy cache migration failed for $bookId: $e',
        name: 'Reader',
        error: e,
        st: st,
      );
    }
  }

  Future<NormalizedBook> openBookWithCache(String bookId, {bool loadChapters = true}) async {
    final cid = 'cache-$bookId-${DateTime.now().millisecondsSinceEpoch}';
    final sw = Stopwatch()..start();
    final cachedMeta = await getCachedMetadata(bookId);
    if (cachedMeta != null) {
      _logger.info(
        'Cache HIT (split) for $bookId in ${sw.elapsedMilliseconds}ms',
        name: 'Reader',
        cid: cid,
      );
      final bookDir = await _getExistingBookDir(bookId);
      final isComplete = await _isSplitCacheComplete(bookDir, cachedMeta);
      if (!loadChapters) {
        return NormalizedBook(
          id: cachedMeta.id,
          title: cachedMeta.title,
          authors: cachedMeta.authors,
          description: cachedMeta.description,
          coverUrl: cachedMeta.coverUrl,
          chapters: [
            for (var i = 0; i < cachedMeta.chapterCount; i++)
              ReaderChapter(
                index: i,
                title: i < cachedMeta.chapterTitles.length
                    ? cachedMeta.chapterTitles[i]
                    : 'Глава ${i + 1}',
                blocks: const [],
              ),
          ],
          metadata: cachedMeta.metadata,
        );
      }

      if (!isComplete) {
        _logger.warning('Split cache is incomplete for $bookId', name: 'Reader');
      } else {
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

      return NormalizedBook(
        id: cachedMeta.id,
        title: cachedMeta.title,
        authors: cachedMeta.authors,
        description: cachedMeta.description,
        coverUrl: cachedMeta.coverUrl,
        chapters: [
          for (var i = 0; i < cachedMeta.chapterCount; i++)
            ReaderChapter(
              index: i,
              title: i < cachedMeta.chapterTitles.length
                  ? cachedMeta.chapterTitles[i]
                  : 'Глава ${i + 1}',
              blocks: const [],
            ),
        ],
        metadata: cachedMeta.metadata,
      );
    }

    // Try legacy monolithic cache
    final cached = await getCachedBook(bookId);
    if (cached != null) {
      _logger.info(
        'Cache HIT (legacy) for $bookId in ${sw.elapsedMilliseconds}ms',
        name: 'Reader',
        cid: cid,
      );
      unawaited(_migrateLegacyCache(bookId, cached));
      return cached;
    }

    _logger.info('Cache MISS for $bookId, parsing fresh', name: 'Reader', cid: cid);
    try {
      final book = await openBook(bookId);
      await _saveSplitCache(bookId, book);
      return book;
    } on TimeoutException {
      await invalidateBookCache(bookId);
      rethrow;
    }
  }
}

final class _CacheSourceFingerprint {
  const _CacheSourceFingerprint({
    required this.format,
    required this.fileSize,
    required this.fileMtime,
    required this.contentHash,
  });

  final String format;
  final int fileSize;
  final int fileMtime;
  final String? contentHash;
}
