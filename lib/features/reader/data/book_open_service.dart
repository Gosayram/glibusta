import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/full_text_search.dart';
import '../../../core/errors/failures.dart';
import '../../../core/formats/book_file_size_policy.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../src/rust/api/api/api.dart' as rust_api;
import '../../library/domain/book_file_repository.dart';
import '../epub/epub_book_adapter.dart';
import '../epub/epub_image_store.dart';
import '../epub/epub_parser.dart' as new_epub;
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/parser_registry.dart';
import 'reader_cache_service.dart';

final bookOpenServiceProvider = Provider<BookOpenService>((ref) {
  final storage = ref.watch(appFileStorageProvider);
  final fileRepo = ref.watch(bookFileRepositoryProvider);
  final ftsService = ref.watch(fullTextSearchProvider);
  final logger = ref.watch(appLoggerProvider);
  return BookOpenService(storage, fileRepo, logger: logger, ftsService: ftsService);
});

class BookOpenService {
  final BookFileRepository _fileRepo;
  final AppLogger _logger;
  late final ReaderCacheService cache;

  BookOpenService(
    AppFileStorage storage,
    this._fileRepo, {
    required AppLogger logger,
    FullTextSearchService? ftsService,
  }) : _logger = logger {
    cache = ReaderCacheService(
      fingerprintProvider: _computeCacheFingerprint,
      storage: storage,
      logger: logger,
      ftsService: ftsService,
    );
  }

  static const Duration _parsingTimeout = Duration(seconds: 60);

  static final _registry = BookParserRegistry.defaultInstance;

  static Future<NormalizedBook> _parseEpubInWorker(
    ({String filePath, String imagesDirPath, String bookId}) args,
  ) async {
    final imageStore = EpubImageStore(Directory(args.imagesDirPath));
    final parser = new_epub.CustomEpubParser(imageStore: imageStore);
    final epubBook = await parser.parse(args.filePath);
    return EpubBookAdapter().toNormalizedBook(epubBook, args.bookId);
  }

  Future<NormalizedBook> openBook(String bookId) async {
    final cid = 'open-$bookId-${DateTime.now().millisecondsSinceEpoch}';
    _logger.info('Opening book', name: 'Reader', cid: cid);
    final filePath = await _fileRepo.getFilePath(bookId);
    if (filePath == null || filePath.isEmpty) {
      throw const BookMissingFailure('Книга не найдена в загрузках');
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
        'Формат не поддерживается: ${(await _fileRepo.getFormat(bookId)).name}',
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
      final bookDir = await cache.getBookDir(effectiveBookId);
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
        return normalized.withCleanedBlocks();
      } on TimeoutException {
        rethrow;
      } on Object catch (e, st) {
        _logger.severe('EPUB parser failed: $e', name: 'Reader', error: e, st: st);
        rethrow;
      }
    }

    final parser = _registry.parserForFormat(bookFormat);
    if (parser == null) {
      throw UnsupportedFormatFailure('Формат не поддерживается: ${bookFormat.name}');
    }
    final book = await parser
        .parseFile(filePath)
        .timeout(
          _parsingTimeout,
          onTimeout: () => throw TimeoutException(
            'Разбор ${bookFormat.name} занял слишком много времени.',
          ),
        );
    final cleaned = book.withCleanedBlocks();
    if (bookFormat != BookFormat.docx || bookId == null) return cleaned;

    return _materializeDocxImages(cleaned, filePath, bookId);
  }

  Future<NormalizedBook> _materializeDocxImages(
    NormalizedBook book,
    String filePath,
    String bookId,
  ) async {
    final assetIds = <String>{
      for (final chapter in book.chapters)
        for (final block in chapter.blocks)
          if (block.type == BlockType.image)
            if (block.imageUrl case final String assetId) assetId,
    };
    if (assetIds.isEmpty) return book;

    final bookDir = await cache.getBookDir(bookId);
    final imagesDir = Directory('${bookDir.path}/docx_images');
    await imagesDir.create(recursive: true);
    final resolved = <String, String>{};

    for (final assetId in assetIds) {
      try {
        final imageFile = File('${imagesDir.path}/${_docxImageFileName(assetId)}');
        if (!await imageFile.exists()) {
          final bytes = await rust_api.getAssetBytes(path: filePath, assetId: assetId);
          await imageFile.writeAsBytes(bytes, flush: true);
        }
        resolved[assetId] = imageFile.path;
      } on Object catch (e, st) {
        _logger.warning(
          'Unable to materialize DOCX image $assetId',
          name: 'Reader',
          error: e,
          st: st,
        );
      }
    }

    return book.withResolvedImageUrls(resolved);
  }

  static String _docxImageFileName(String assetId) =>
      Uri.encodeComponent(assetId).replaceAll('%', '_');

  String _extractBookId(String filePath) {
    final name = filePath.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }

  Future<CacheSourceFingerprint?> _computeCacheFingerprint(
    String bookId,
  ) async {
    final filePath = await _fileRepo.getFilePath(bookId);
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    final stat = await file.stat();
    final contentHash = await _fileRepo.getContentHash(bookId);
    return CacheSourceFingerprint(
      format: detectBookFormat(filePath).name,
      fileSize: stat.size,
      fileMtime: stat.modified.millisecondsSinceEpoch,
      contentHash: contentHash,
    );
  }

  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) => cache.getMetadata(bookId);

  Future<ReaderChapter?> loadChapter(String bookId, int index) => cache.getChapter(bookId, index);

  Future<void> invalidateBookCache(
    String bookId, {
    bool preserveImages = false,
  }) => cache.invalidate(bookId, preserveImages: preserveImages);

  Future<NormalizedBook?> getCachedBook(String bookId) => cache.getCachedBook(bookId);

  Future<NormalizedBook> openBookWithCache(
    String bookId, {
    bool loadChapters = true,
  }) async {
    final cid = 'cache-$bookId-${DateTime.now().millisecondsSinceEpoch}';
    final sw = Stopwatch()..start();
    final cachedMeta = await cache.getMetadata(bookId);
    if (cachedMeta != null) {
      final isComplete = await cache.isCacheValid(bookId, cachedMeta);
      if (!isComplete) {
        _logger.warning(
          'Split cache is stale or incomplete for $bookId; reparsing source',
          name: 'Reader',
        );
        await cache.invalidate(bookId, preserveImages: true);
      } else {
        _logger.info(
          'Cache HIT (split) for $bookId in ${sw.elapsedMilliseconds}ms',
          name: 'Reader',
          cid: cid,
        );
        if (!loadChapters) {
          return _bookFromMetadata(cachedMeta);
        }
        final chapters = <ReaderChapter>[];
        for (var i = 0; i < cachedMeta.chapterCount; i++) {
          final chapter = await cache.getChapter(bookId, i);
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
        _logger.warning(
          'Split cache lost chapters while loading $bookId; reparsing source',
          name: 'Reader',
        );
        await cache.invalidate(bookId, preserveImages: true);
      }
    }

    final cached = await cache.getCachedBook(bookId);
    if (cached != null) {
      _logger.info(
        'Cache HIT (legacy) for $bookId in ${sw.elapsedMilliseconds}ms',
        name: 'Reader',
        cid: cid,
      );
      unawaited(cache.migrateLegacyCache(bookId, cached));
      return cached;
    }

    _logger.info(
      'Cache MISS for $bookId, parsing fresh',
      name: 'Reader',
      cid: cid,
    );
    try {
      final book = await openBook(bookId);
      await cache.putBook(bookId, book);
      return book;
    } on TimeoutException {
      await cache.invalidate(bookId, preserveImages: true);
      rethrow;
    }
  }

  NormalizedBook _bookFromMetadata(NormalizedBookMetadata metadata) {
    return NormalizedBook(
      id: metadata.id,
      title: metadata.title,
      authors: metadata.authors,
      description: metadata.description,
      coverUrl: metadata.coverUrl,
      chapters: [
        for (var i = 0; i < metadata.chapterCount; i++)
          ReaderChapter(
            index: i,
            title: i < metadata.chapterTitles.length ? metadata.chapterTitles[i] : 'Глава ${i + 1}',
            blocks: const [],
          ),
      ],
      metadata: metadata.metadata,
    );
  }
}
