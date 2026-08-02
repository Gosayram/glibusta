import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/full_text_search.dart';
import '../../../core/errors/failures.dart';
import '../../../core/fonts/epub_font_loader.dart';
import '../../../core/formats/book_file_size_policy.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../src/rust/api/api/api.dart' as rust_api;
import '../../library/domain/book_file_repository.dart';
import 'content_transformers.dart';
import 'parsers/book_parser.dart';
import 'parsers/format_detector.dart';
import 'parsers/normalized_book.dart';
import 'parsers/parser_lookup.dart';
import 'reader_cache_service.dart';

enum BookOpenError {
  corruptFile('Файл повреждён. Попробуйте загрузить заново.'),
  unsupportedFormat('Формат не поддерживается.'),
  missingContent('Содержимое книги отсутствует или повреждено.'),
  emptyBook('Книга не содержит текста.');

  const BookOpenError(this.userMessage);
  final String userMessage;
}

BookOpenError _classifyBookOpenError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('zip') ||
      message.contains('archive') ||
      message.contains('corrupt') ||
      message.contains('mimetype') ||
      message.contains('unexpected end') ||
      message.contains('invalid header') ||
      message.contains('bad zip') ||
      message.contains('загру') ||
      error is ArchiveException) {
    return BookOpenError.corruptFile;
  }
  if (message.contains('opf') ||
      message.contains('container.xml') ||
      message.contains('rootfile') ||
      message.contains('package document') ||
      message.contains('not found') && message.contains('epub')) {
    return BookOpenError.missingContent;
  }
  if (message.contains('unsupported') || message.contains('не поддерживается')) {
    return BookOpenError.unsupportedFormat;
  }
  return BookOpenError.corruptFile;
}

BookOpenFailure _toBookOpenFailure(Object error) {
  final classified = _classifyBookOpenError(error);
  switch (classified) {
    case BookOpenError.corruptFile:
      return CorruptFileFailure(error.toString());
    case BookOpenError.missingContent:
      return MissingContentFailure(error.toString());
    case BookOpenError.unsupportedFormat:
      return UnsupportedFormatFailure(error.toString());
    case BookOpenError.emptyBook:
      return const CacheCorruptedFailure('Книга не содержит текста');
  }
}

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

  static final _parsers = parserForFormatMap;

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
    final parser = _parsers[bookFormat];
    if (parser == null) {
      throw UnsupportedFormatFailure('Формат не поддерживается: ${bookFormat.name}');
    }
    Future<NormalizedBook> parseWithTimeout(BookParser selectedParser) => selectedParser
        .parseFile(filePath)
        .timeout(
          _parsingTimeout,
          onTimeout: () => throw TimeoutException(
            'Разбор ${bookFormat.name} занял слишком много времени.',
          ),
        );

    NormalizedBook book;
    try {
      book = await parseWithTimeout(parser);
    } on ParserFailure catch (e) {
      if (filePath.toLowerCase().endsWith('.zip')) {
        final cbzParser = _parsers[BookFormat.cbz]!;
        book = await parseWithTimeout(cbzParser);
      } else {
        throw _toBookOpenFailure(e);
      }
    }
    final cleaned = book.withCleanedBlocks();
    final pipeline = ContentTransformerPipeline([
      RichSpanColorTransformer(),
    ]);
    final transformed = pipeline.transform(cleaned);

    if (bookId != null &&
        (bookFormat == BookFormat.epub ||
            bookFormat == BookFormat.docx ||
            bookFormat == BookFormat.cbz)) {
      return _materializeArchiveImages(transformed, filePath, bookId);
    }
    return transformed;
  }

  Future<NormalizedBook> _materializeArchiveImages(
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
        final bytes = await rust_api.getAssetBytes(path: filePath, assetId: assetId);
        final temporaryFile = File('${imageFile.path}.tmp');
        await temporaryFile.writeAsBytes(bytes, flush: true);
        await temporaryFile.rename(imageFile.path);
        resolved[assetId] = imageFile.path;
      } on Object catch (e, st) {
        _logger.warning(
          'Unable to materialize archive image $assetId',
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

  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    final metadata = await cache.getMetadata(bookId);
    if (metadata == null || !await cache.isCacheValid(bookId, metadata)) {
      return null;
    }
    return metadata;
  }

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
          final book = _bookFromMetadata(cachedMeta);
          await _loadEmbeddedFonts(book, bookId);
          return book;
        }
        final chapters = <ReaderChapter>[];
        for (var i = 0; i < cachedMeta.chapterCount; i++) {
          final chapter = await cache.getChapter(bookId, i);
          if (chapter != null) {
            chapters.add(chapter);
          }
        }
        if (chapters.length == cachedMeta.chapterCount) {
          final book = NormalizedBook(
            id: cachedMeta.id,
            title: cachedMeta.title,
            authors: cachedMeta.authors,
            description: cachedMeta.description,
            coverUrl: cachedMeta.coverUrl,
            chapters: chapters,
            metadata: cachedMeta.metadata,
          );
          await _loadEmbeddedFonts(book, bookId);
          return book;
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
      await _loadEmbeddedFonts(cached, bookId);
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

  Future<void> _loadEmbeddedFonts(NormalizedBook book, String bookId) async {
    final fontMap = book.metadata?['fonts'];
    if (fontMap is! Map || fontMap.isEmpty) return;
    final filePath = await _fileRepo.getFilePath(bookId);
    if (filePath == null) return;
    await EpubFontLoader.loadFonts(
      epubPath: filePath,
      fontMap: Map<String, dynamic>.from(fontMap),
    );
  }

  NormalizedBook _bookFromMetadata(NormalizedBookMetadata metadata) {
    return NormalizedBook(
      id: metadata.id,
      title: metadata.title,
      authors: metadata.authors,
      description: metadata.description,
      coverUrl: metadata.coverUrl,
      chapters: metadata.buildChapters(),
      metadata: metadata.metadata,
    );
  }
}
