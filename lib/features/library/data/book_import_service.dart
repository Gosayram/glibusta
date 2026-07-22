import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/failures.dart';
import '../../../core/formats/book_file_size_policy.dart';
import '../../../core/formats/format_capability.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../core/storage/external_book_file.dart';
import '../../../core/storage/storage_bridge.dart';

import '../../reader/data/parsers/book_parser.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../../reader/data/parsers/normalized_book.dart';
import '../../reader/data/parsers/parser_registry.dart';
import 'cover_extraction_service.dart';
import 'inspectors/book_inspection_result.dart';

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final database = ref.watch(databaseProvider);
  final storage = ref.watch(appFileStorageProvider);
  final coverService = ref.watch(coverExtractionServiceProvider);
  return BookImportService(database, storage, coverService);
});

class BookImportService {
  final AppDatabase _database;
  final AppFileStorage _storage;
  final CoverExtractionService _coverService;
  final _logger = AppLogger();

  BookImportService(
    this._database,
    this._storage,
    this._coverService, {
    BookParserRegistry? parserRegistry,
  }) : _registry = parserRegistry ?? BookParserRegistry.defaultInstance;

  final BookParserRegistry _registry;
  final Map<String, Future<ImportResult>> _importLocks = {};
  final Map<String, Future<ImportResult>> _contentImportLocks = {};

  static String generateAuthorId(String name) {
    final normalized = name.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    return 'author_${sha256.convert(bytes).toString().substring(0, 16)}';
  }

  /// Import a file from its inspection result.
  Future<ImportResult> importFromInspection(
    BookFileInspectionResult inspection,
  ) async {
    _logger.info(
      'Import from inspection: ${inspection.decision.name} - ${inspection.title ?? inspection.path}',
      name: 'Import',
    );
    if (inspection.decision == ImportDecision.duplicate) {
      return ImportResult.duplicate(inspection.title ?? 'unknown', inspection.hash);
    }
    if (inspection.decision == ImportDecision.corrupted) {
      return ImportResult.failure(inspection.reason ?? 'Файл повреждён');
    }
    if (inspection.decision == ImportDecision.unsupported) {
      return ImportResult.failure(inspection.reason ?? 'Формат не поддерживается');
    }
    if (inspection.decision == ImportDecision.needsEncodingSelection) {
      return ImportResult.needsEncoding(
        inspection.title ?? 'Неизвестная кодировка',
        inspection.encoding,
      );
    }

    return _coalesceImport(inspection.path, () async {
      if (inspection.decision == ImportDecision.importAsDocument) {
        return _doDocumentImport(inspection);
      }
      return _doImport(inspection.path, forcedEncoding: inspection.encoding);
    });
  }

  /// Import a file by path (runs full inspection + import).
  Future<ImportResult> importFile(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    if (!importableExtensions.contains(ext)) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult.failure('Файл не найден: $filePath');
    }
    final size = await file.length();
    if (size < 100) {
      return ImportResult.failure('Файл слишком мал: $size байт');
    }
    final format = bookFormatForImportExtension(ext);
    if (isBookFileTooLarge(format, size)) {
      return ImportResult.failure(bookFileTooLargeMessage(format, size));
    }
    return _coalesceImport(filePath, () async {
      if (const FormatCapabilityService().isDocumentOnly(format)) {
        return _doDocumentImport(
          BookFileInspectionResult(
            path: filePath,
            format: format,
            decision: ImportDecision.importAsDocument,
            hash: '',
            fileSize: size,
          ),
        );
      }
      return _doImport(filePath);
    });
  }

  /// Shares one in-flight import result among requests for the same local file.
  ///
  /// A wait-then-retry lock still runs a second import after the first finishes,
  /// which can turn a simultaneous import into a spurious "duplicate" result.
  Future<ImportResult> _coalesceImport(
    String filePath,
    Future<ImportResult> Function() import,
  ) {
    final normalizedPath = filePath.replaceAll(r'\', '/');
    return _coalesceByKey(_importLocks, normalizedPath, import);
  }

  /// Shares one in-flight import after its content identity is known.
  ///
  /// The format and explicit encoding remain part of the key because both can
  /// change how identical bytes are interpreted.
  Future<ImportResult> _coalesceContentImport(
    _ImportCtx ctx,
    Future<ImportResult> Function() import,
  ) {
    final key = _contentImportKey(ctx.contentHash, ctx.format, ctx.forcedEncoding);
    return _coalesceByKey(_contentImportLocks, key, import);
  }

  Future<ImportResult> _coalesceExternalContentImport({
    required String contentHash,
    required BookFormat format,
    required File cacheFile,
    required Future<ImportResult> Function() import,
  }) async {
    final key = _contentImportKey(contentHash, format, null);
    final activeImport = _contentImportLocks[key];
    if (activeImport != null) {
      await _tryDelete(cacheFile.path);
      return activeImport;
    }
    return _coalesceByKey(_contentImportLocks, key, import);
  }

  String _contentImportKey(String contentHash, BookFormat format, String? forcedEncoding) =>
      '$contentHash:${format.name}:${forcedEncoding ?? ''}';

  Future<ImportResult> _coalesceByKey(
    Map<String, Future<ImportResult>> locks,
    String key,
    Future<ImportResult> Function() import,
  ) {
    final activeImport = locks[key];
    if (activeImport != null) return activeImport;

    late final Future<ImportResult> result;
    result = Future.sync(import).whenComplete(() {
      if (identical(locks[key], result)) {
        final removedImport = locks.remove(key);
        assert(
          identical(removedImport, result),
          'An import lock must only remove its own in-flight result.',
        );
      }
    });
    locks[key] = result;
    return result;
  }

  Future<ImportResult> _doImport(String filePath, {String? forcedEncoding}) async {
    final ctx = _ImportCtx(filePath: filePath, forcedEncoding: forcedEncoding);

    final inspectResult = await _inspect(ctx);
    if (inspectResult != null) return inspectResult;

    await _readAndHash(ctx);
    return _coalesceContentImport(ctx, () => _completeBookImport(ctx));
  }

  Future<ImportResult> _completeBookImport(_ImportCtx ctx) async {
    final dedupResult = await _deduplicate(ctx);
    if (dedupResult != null) return dedupResult;

    final parseResult = await _parseMetadata(ctx);
    if (parseResult != null) return parseResult;

    try {
      await _copyToStorage(ctx);
      await _registerBookInDb(ctx);
    } on Object catch (e) {
      _logger.warning('Import failed for ${ctx.filePath}: $e', name: 'Import', error: e);
      await _cleanupFailedImport(ctx);
      return ImportResult.failure(_friendlyImportError(e));
    }

    _scheduleCoverExtraction(ctx);
    return ImportResult.success(ctx.book!.title);
  }

  Future<ImportResult> _doDocumentImport(BookFileInspectionResult inspection) async {
    final ctx = _ImportCtx(filePath: inspection.path, inspection: inspection);

    final inspectResult = await _inspectDocument(ctx);
    if (inspectResult != null) return inspectResult;

    await _readAndHash(ctx);
    return _coalesceContentImport(ctx, () => _completeDocumentImport(ctx));
  }

  Future<ImportResult> _completeDocumentImport(_ImportCtx ctx) async {
    final dedupResult = await _deduplicate(ctx);
    if (dedupResult != null) return dedupResult;

    ctx.title =
        ctx.inspection!.title ?? ctx.filePath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');

    try {
      await _copyToStorage(ctx);
      await _registerDocumentInDb(ctx);
    } on Object catch (e) {
      _logger.warning(
        'Document import failed for ${ctx.filePath}: $e',
        name: 'Import',
        error: e,
      );
      await _cleanupFailedImport(ctx);
      return ImportResult.failure(_friendlyImportError(e));
    }

    return ImportResult.success(ctx.title!);
  }

  Future<ImportResult?> _inspect(_ImportCtx ctx) async {
    ctx.file = File(ctx.filePath);
    if (!await ctx.file.exists()) {
      return ImportResult.failure('Файл не найден: ${ctx.filePath}');
    }
    ctx.ext = ctx.filePath.split('.').last.toLowerCase();
    ctx.format = bookFormatForImportExtension(ctx.ext);
    final size = await ctx.file.length();
    if (isBookFileTooLarge(ctx.format, size)) {
      return ImportResult.failure(bookFileTooLargeMessage(ctx.format, size));
    }
    return null;
  }

  Future<ImportResult?> _inspectDocument(_ImportCtx ctx) async {
    ctx.file = File(ctx.filePath);
    if (!await ctx.file.exists()) {
      return ImportResult.failure('Файл не найден: ${ctx.filePath}');
    }
    ctx.ext = ctx.filePath.split('.').last.toLowerCase();
    ctx.format = bookFormatForImportExtension(ctx.ext);
    if (ctx.format == BookFormat.unknown) {
      return ImportResult.failure('Формат не поддерживается: .${ctx.ext}');
    }
    final size = await ctx.file.length();
    if (isBookFileTooLarge(ctx.format, size)) {
      return ImportResult.failure(bookFileTooLargeMessage(ctx.format, size));
    }
    return null;
  }

  Future<void> _readAndHash(_ImportCtx ctx) async {
    final fileSize = await ctx.file.length();
    if (fileSize == 0) {
      throw StateError('Файл пуст: ${ctx.filePath}');
    }
    if (isBookFileTooLarge(ctx.format, fileSize)) {
      throw StateError(bookFileTooLargeMessage(ctx.format, fileSize));
    }
    ctx.fileSize = fileSize;
    ctx.contentHash = ctx.inspection != null && ctx.inspection!.hash.isNotEmpty
        ? ctx.inspection!.hash
        : (await sha256.bind(ctx.file.openRead()).first).toString();
    ctx.bookId = ctx.contentHash;
  }

  Future<ImportResult?> _deduplicate(_ImportCtx ctx) async {
    final existing = await _findByHash(ctx.contentHash);
    if (existing != null) {
      _logger.info(
        'Duplicate detected: ${existing.title} (${ctx.contentHash.substring(0, 8)})',
        name: 'Import',
      );
      return ImportResult.duplicate(
        existing.title,
        ctx.contentHash,
        existingBookId: existing.id,
      );
    }
    return null;
  }

  Future<ImportResult?> _parseMetadata(_ImportCtx ctx) async {
    final parser =
        _registry.parserForExtension(ctx.ext) ??
        (ctx.ext == 'zip' ? _registry.parserFor(BookFormat.fb2) : null);
    if (parser == null) {
      return ImportResult.failure(_unsupportedReaderMessage(ctx.ext));
    }

    try {
      try {
        ctx.book = await _parseBook(parser, ctx);
      } on ParserFailure catch (_) {
        if (ctx.ext != 'zip') rethrow;
        ctx.book = await _parseBook(_registry.parserFor(BookFormat.cbz), ctx);
        ctx.format = BookFormat.cbz;
      }

      ctx.coverBytes = _coverBytesForBook(ctx.book!);
    } on Object catch (e) {
      return ImportResult.failure(_friendlyImportError(e));
    }
    return null;
  }

  Future<NormalizedBook> _parseBook(BookParser parser, _ImportCtx ctx) async {
    final forcedEncoding = ctx.forcedEncoding;
    if (forcedEncoding == null) {
      return parser.parseFile(ctx.filePath);
    }
    final bytes = ctx.bytes ??= await ctx.file.readAsBytes();
    return parser.parse(
      bytes,
      fileName: ctx.filePath.split('/').last,
      forcedEncoding: forcedEncoding,
    );
  }

  Future<void> _copyToStorage(_ImportCtx ctx) async {
    ctx.targetFile = await _storage.bookFile(ctx.bookId, ctx.format);
    await ctx.targetFile!.parent.create(recursive: true);
    await ctx.file.copy(ctx.targetFile!.path);
  }

  Future<void> _registerBookInDb(_ImportCtx ctx) async {
    final book = ctx.book!;
    ctx.authorIds = [];
    final authorCompanions = <AuthorsCompanion>[];
    for (final authorName in book.authors) {
      final authorId = generateAuthorId(authorName);
      ctx.authorIds.add(authorId);
      authorCompanions.add(AuthorsCompanion.insert(id: authorId, name: authorName));
    }
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.authors, authorCompanions);
    });

    await _database.transaction(() async {
      await _database
          .into(_database.savedBooks)
          .insertOnConflictUpdate(
            SavedBooksCompanion.insert(
              id: ctx.bookId,
              title: book.title,
              authorIds: Value(ctx.authorIds),
              description: Value(book.description),
              coverUrl: Value(book.coverUrl),
              sourceUrl: Value(ctx.sourceUrl ?? ctx.filePath),
              contentHash: Value(ctx.contentHash),
              fileSize: Value(ctx.fileSize),
              filePath: Value(ctx.targetFile!.path),
              detectedEncoding: Value(ctx.forcedEncoding),
              encodingSource: ctx.forcedEncoding != null
                  ? const Value('manual')
                  : const Value.absent(),
              userForcedEncoding: Value(ctx.forcedEncoding),
              storageMode: Value(ctx.storageMode ?? 'internal'),
              externalUri: Value(ctx.externalUri),
            ),
          );

      await _database
          .into(_database.downloads)
          .insertOnConflictUpdate(
            DownloadsCompanion.insert(
              id: ctx.bookId,
              bookId: ctx.bookId,
              bookTitle: Value(book.title),
              format: formatToDbString(formatForExtension(ctx.ext)),
              sourceUrl: ctx.sourceUrl ?? ctx.filePath,
              targetPath: Value(ctx.targetFile!.path),
              status: DownloadStatusDb.completed,
            ),
          );
    });
  }

  Future<void> _registerDocumentInDb(_ImportCtx ctx) async {
    await _database.transaction(() async {
      await _database
          .into(_database.savedBooks)
          .insertOnConflictUpdate(
            SavedBooksCompanion.insert(
              id: ctx.bookId,
              title: ctx.title!,
              authorIds: const Value([]),
              description: Value(_documentDescription(ctx.format)),
              sourceUrl: Value(ctx.sourceUrl ?? ctx.filePath),
              contentHash: Value(ctx.contentHash),
              fileSize: Value(ctx.fileSize),
              filePath: Value(ctx.targetFile!.path),
              storageMode: Value(ctx.storageMode ?? 'internal'),
              externalUri: Value(ctx.externalUri),
            ),
          );

      await _database
          .into(_database.downloads)
          .insertOnConflictUpdate(
            DownloadsCompanion.insert(
              id: ctx.bookId,
              bookId: ctx.bookId,
              bookTitle: Value(ctx.title!),
              format: ctx.format.name,
              sourceUrl: ctx.sourceUrl ?? ctx.filePath,
              targetPath: Value(ctx.targetFile!.path),
              status: DownloadStatusDb.completed,
            ),
          );
    });
  }

  void _scheduleCoverExtraction(_ImportCtx ctx) {
    unawaited(() async {
      try {
        await _extractCoverBackground(
          ctx.bookId,
          ctx.targetFile!.path,
          ctx.ext,
          coverBytes: ctx.coverBytes,
        );
      } on Object catch (e, st) {
        _logger.warning('Cover extraction for ${ctx.bookId}: $e', name: 'Import', error: e, st: st);
      }
    }());
  }

  Future<void> _cleanupFailedImport(_ImportCtx ctx) async {
    try {
      if (ctx.targetFile != null) {
        final f = ctx.targetFile!;
        if (await f.exists()) await f.delete();
      }
      await _deletePartialImportRows(ctx.bookId);
    } on Object catch (e) {
      _logger.warning(
        'Failed to cleanup failed import for ${ctx.bookId}: $e',
        name: 'Import',
        error: e,
      );
    }
  }

  /// Import a book from an external SAF URI into the app library.
  Future<ImportResult> importFromExternal(
    ExternalBookFile external, {
    required StorageBridge bridge,
  }) async {
    _logger.info('Import from external: ${external.name} (${external.extension})', name: 'Import');
    final ext = external.extension.toLowerCase();
    if (!importableExtensions.contains(ext)) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }
    final format = bookFormatForImportExtension(ext);
    if (external.size > 0 && isBookFileTooLarge(format, external.size)) {
      return ImportResult.failure(bookFileTooLargeMessage(format, external.size));
    }

    File? cacheFile;
    try {
      // SAF providers may report an unknown or stale size. Pass the same
      // per-format policy to Android so it stops streaming before a too-large
      // TXT (or any other format) consumes cache storage.
      final cachedPath = await bridge.copyToCache(
        external.uri,
        maxBytes: maxReadableBookBytes(format),
      );
      if (cachedPath == null) {
        return ImportResult.failure('Не удалось прочитать файл: ${external.name}');
      }
      final cachedFile = File(cachedPath);
      cacheFile = cachedFile;
      if (!await cachedFile.exists() || await cachedFile.length() == 0) {
        await _tryDelete(cachedPath);
        return ImportResult.failure('Файл пуст: ${external.name}');
      }

      final fileSize = await cachedFile.length();
      if (isBookFileTooLarge(format, fileSize)) {
        await _tryDelete(cachedPath);
        return ImportResult.failure(bookFileTooLargeMessage(format, fileSize));
      }

      final digest = await sha256.bind(cachedFile.openRead()).first;
      final contentHash = digest.toString();
      return _coalesceExternalContentImport(
        contentHash: contentHash,
        format: format,
        cacheFile: cachedFile,
        import: () => _importCachedExternalBook(
          external: external,
          cacheFile: cachedFile,
          format: format,
          fileSize: fileSize,
          contentHash: contentHash,
        ),
      );
    } on Object catch (e) {
      _logger.warning(
        'External import failed for ${external.name}: $e',
        name: 'Import',
        error: e,
      );
      if (cacheFile != null) {
        await _tryDelete(cacheFile.path);
      }
      return ImportResult.failure(_friendlyImportError(e));
    }
  }

  Future<ImportResult> _importCachedExternalBook({
    required ExternalBookFile external,
    required File cacheFile,
    required BookFormat format,
    required int fileSize,
    required String contentHash,
  }) async {
    final ext = external.extension.toLowerCase();
    final bookId = contentHash;
    var resolvedFormat = format;
    try {
      final existing = await _findByHash(contentHash);
      if (existing != null) {
        await _tryDelete(cacheFile.path);
        return ImportResult.duplicate(existing.title, contentHash, existingBookId: existing.id);
      }

      if (const FormatCapabilityService().isDocumentOnly(resolvedFormat)) {
        final title = external.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final targetFile = await _storage.bookFile(bookId, resolvedFormat);
        await targetFile.parent.create(recursive: true);
        await _moveCacheFileToStorage(cacheFile, targetFile);

        await _database.transaction(() async {
          await _database
              .into(_database.savedBooks)
              .insertOnConflictUpdate(
                SavedBooksCompanion.insert(
                  id: bookId,
                  title: title,
                  authorIds: const Value([]),
                  description: Value(_documentDescription(resolvedFormat)),
                  sourceUrl: Value(external.uri),
                  contentHash: Value(contentHash),
                  fileSize: Value(fileSize),
                  filePath: Value(targetFile.path),
                  storageMode: const Value('external'),
                  externalUri: Value(external.uri),
                ),
              );

          await _database
              .into(_database.downloads)
              .insertOnConflictUpdate(
                DownloadsCompanion.insert(
                  id: bookId,
                  bookId: bookId,
                  bookTitle: Value(title),
                  format: resolvedFormat.name,
                  sourceUrl: external.uri,
                  targetPath: Value(targetFile.path),
                  status: DownloadStatusDb.completed,
                ),
              );
        });

        return ImportResult.success(title);
      }

      final parser =
          _registry.parserForExtension(ext) ??
          (ext == 'zip' ? _registry.parserFor(BookFormat.fb2) : null);
      if (parser == null) {
        return ImportResult.failure(_unsupportedReaderMessage(ext));
      }

      late final NormalizedBook book;
      try {
        book = await parser.parseFile(cacheFile.path);
      } on ParserFailure catch (_) {
        if (ext != 'zip') rethrow;
        book = await _registry.parserFor(BookFormat.cbz).parseFile(cacheFile.path);
        resolvedFormat = BookFormat.cbz;
      }

      final extCoverBytes = _coverBytesForBook(book);

      final targetFile = await _storage.bookFile(
        bookId,
        resolvedFormat,
      );
      await targetFile.parent.create(recursive: true);
      await _moveCacheFileToStorage(cacheFile, targetFile);

      final extAuthorIds = <String>[];
      final extAuthorCompanions = <AuthorsCompanion>[];
      for (final authorName in book.authors) {
        final authorId = generateAuthorId(authorName);
        extAuthorIds.add(authorId);
        extAuthorCompanions.add(AuthorsCompanion.insert(id: authorId, name: authorName));
      }
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(_database.authors, extAuthorCompanions);
      });

      await _database.transaction(() async {
        await _database
            .into(_database.savedBooks)
            .insertOnConflictUpdate(
              SavedBooksCompanion.insert(
                id: bookId,
                title: book.title,
                authorIds: Value(extAuthorIds),
                description: Value(book.description),
                coverUrl: Value(book.coverUrl),
                sourceUrl: Value(external.uri),
                contentHash: Value(contentHash),
                fileSize: Value(fileSize),
                filePath: Value(targetFile.path),
                storageMode: const Value('external'),
                externalUri: Value(external.uri),
              ),
            );

        await _database
            .into(_database.downloads)
            .insertOnConflictUpdate(
              DownloadsCompanion.insert(
                id: bookId,
                bookId: bookId,
                bookTitle: Value(book.title),
                format: formatToDbString(resolvedFormat),
                sourceUrl: external.uri,
                targetPath: Value(targetFile.path),
                status: DownloadStatusDb.completed,
              ),
            );
      });

      unawaited(() async {
        try {
          await _extractCoverBackground(bookId, targetFile.path, ext, coverBytes: extCoverBytes);
        } on Object catch (e, st) {
          _logger.warning('Cover extraction for $bookId: $e', name: 'Import', error: e, st: st);
        }
      }());

      return ImportResult.success(book.title);
    } on Object catch (e) {
      _logger.warning(
        'External import failed for ${external.name}: $e',
        name: 'Import',
        error: e,
      );
      await _tryDelete(cacheFile.path);
      try {
        final targetFile = await _storage.bookFile(bookId, resolvedFormat);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await _deletePartialImportRows(bookId);
      } on Object catch (cleanupError) {
        _logger.warning(
          'External import cleanup failed for $bookId: $cleanupError',
          name: 'Import',
          error: cleanupError,
        );
      }
      return ImportResult.failure(_friendlyImportError(e));
    }
  }

  /// Moves an SAF cache file into the app directory, copying across volumes
  /// when the platform rejects an atomic rename.
  Future<void> _moveCacheFileToStorage(File cacheFile, File targetFile) async {
    try {
      await cacheFile.rename(targetFile.path);
    } on FileSystemException {
      await cacheFile.copy(targetFile.path);
      await _tryDelete(cacheFile.path);
    }
  }

  String _friendlyImportError(Object e) {
    final msg = e.toString();
    if (msg.contains('Permission denied') || msg.contains('EPERM')) {
      return 'Нет доступа к файлу. Проверьте разрешения приложения.';
    }
    if (msg.contains('No space left') || msg.contains('ENOSPC')) {
      return 'Недостаточно места на диске.';
    }
    if (msg.contains('FileSystemException')) {
      return 'Ошибка файловой системы: $e';
    }
    return 'Ошибка при импорте: $e';
  }

  Future<ImportBatchResult> importDirectory(
    String dirPath, {
    bool Function()? isCancelled,
    void Function(int current, int total, String fileName)? onProgress,
    int circuitBreakerThreshold = 3,
  }) async {
    _logger.info('Import directory: $dirPath', name: 'Import');
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      _logger.warning('Directory not found: $dirPath', name: 'Import');
      return ImportBatchResult(directory: dirPath, results: [], error: 'Директория не найдена');
    }

    final importableFiles = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (importableExtensions.contains(ext)) {
          importableFiles.add(entity);
        }
      }
    }

    if (importableFiles.isEmpty) {
      return ImportBatchResult(directory: dirPath, results: []);
    }

    final fileResults = <ImportFileResult>[];
    var consecutiveFailures = 0;
    var circuitBroken = false;
    final totalFiles = importableFiles.length;

    for (var i = 0; i < importableFiles.length; i++) {
      if (isCancelled != null && isCancelled()) {
        _logger.info('Directory import cancelled', name: 'Import');
        break;
      }

      if (circuitBroken) break;

      final entity = importableFiles[i];
      final fileName = entity.path.split('/').last;
      onProgress?.call(i + 1, totalFiles, fileName);

      final size = await entity.length();
      final result = await importFile(entity.path);
      fileResults.add(
        ImportFileResult(path: entity.path, sizeBytes: size, result: result),
      );

      if (result.isSuccess || result.isDuplicate || result.needsEncodingSelection) {
        consecutiveFailures = 0;
      } else {
        consecutiveFailures++;
        if (consecutiveFailures >= circuitBreakerThreshold) {
          circuitBroken = true;
          _logger.warning(
            'Circuit breaker triggered after $consecutiveFailures consecutive failures',
            name: 'Import',
          );
        }
      }

      if (!result.isSuccess && !result.isDuplicate && !result.needsEncodingSelection) {
        _logger.warning(
          'Directory import failed for ${entity.path} (${formatBytes(size)}): ${result.error}',
          name: 'Import',
        );
      }
    }

    final batch = ImportBatchResult(
      directory: dirPath,
      fileResults: fileResults,
      circuitBroken: circuitBroken,
    );
    _logger.info(
      'Directory import complete: ${batch.successCount} imported, '
      '${batch.duplicateCount} duplicates, ${batch.failureCount} errors'
      '${circuitBroken ? ' (circuit breaker)' : ''}',
      name: 'Import',
    );
    return batch;
  }

  Future<SavedBook?> _findByHash(String hash) async {
    final rows = await (_database.select(
      _database.savedBooks,
    )..where((t) => t.contentHash.equals(hash))).get();
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> _deletePartialImportRows(String bookId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.downloads)..where((row) => row.bookId.equals(bookId))).go();
      await (_database.delete(_database.savedBooks)..where((row) => row.id.equals(bookId))).go();
    });
  }

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on Object catch (e) {
      _logger.warning('Failed to delete file $path: $e', name: 'Import', error: e);
    }
  }

  Future<void> _extractCoverBackground(
    String bookId,
    String filePath,
    String format, {
    Uint8List? coverBytes,
  }) async {
    try {
      _logger.info('Extracting cover for $bookId', name: 'Import');
      final coverPath = await _coverService.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        format: format,
        coverBytes: coverBytes,
      );
      if (coverPath != null) {
        await (_database.update(_database.savedBooks)..where((t) => t.id.equals(bookId))).write(
          SavedBooksCompanion(
            coverPath: Value(coverPath),
            coverStatus: const Value('ready'),
          ),
        );
        _logger.info('Cover extracted for $bookId: $coverPath', name: 'Import');
      } else {
        _logger.info('No cover found for $bookId', name: 'Import');
      }
    } on Object catch (e) {
      _logger.warning('Cover extraction failed for $bookId: $e', name: 'Import', error: e);
    }
  }

  Uint8List? _coverBytesForBook(NormalizedBook book) {
    final metadataCover = book.metadata?['mobiCoverBytes'];
    if (metadataCover is Uint8List && metadataCover.isNotEmpty) {
      return metadataCover;
    }
    return coverBytesFromDataUri(book.coverUrl);
  }
}

/// Decodes parser-provided image data without allowing a malformed cover URL
/// to fail book import. Rust MOBI parsing exposes cover data through `coverUrl`
/// because arbitrary JSON metadata is opaque across the bridge.
@visibleForTesting
Uint8List? coverBytesFromDataUri(String? coverUrl, {int maxBytes = 50 * 1024 * 1024}) {
  if (coverUrl == null) return null;
  final separator = coverUrl.indexOf(',');
  if (separator <= 0) return null;
  final metadata = coverUrl.substring(0, separator).toLowerCase();
  if (!metadata.startsWith('data:image/') || !metadata.contains(';base64')) {
    return null;
  }
  final encoded = coverUrl.substring(separator + 1);
  final maxEncodedBytes = ((maxBytes + 2) ~/ 3) * 4;
  if (encoded.length > maxEncodedBytes) return null;
  try {
    final decoded = base64Decode(encoded);
    return decoded.length <= maxBytes ? Uint8List.fromList(decoded) : null;
  } on FormatException {
    return null;
  }
}

class _ImportCtx {
  _ImportCtx({
    required this.filePath,
    this.forcedEncoding,
    this.inspection,
  });

  final String filePath;
  final String? forcedEncoding;
  final BookFileInspectionResult? inspection;
  String? sourceUrl;
  String? storageMode;
  String? externalUri;

  late final String ext;
  late BookFormat format;
  late final File file;
  Uint8List? bytes;
  late final int fileSize;
  late final String contentHash;
  String bookId = '';
  String? title;
  NormalizedBook? book;
  File? targetFile;
  List<String> authorIds = [];
  Uint8List? coverBytes;
}

@visibleForTesting
BookFormat bookFormatForImportExtension(String ext) {
  final lower = ext.toLowerCase();
  if (lower == 'zip') return BookFormat.fb2;
  return formatForExtension(lower);
}

String _unsupportedReaderMessage(String ext) {
  final upper = ext.toUpperCase();
  return '$upper распознан, но чтение этого формата пока не поддерживается';
}

String _documentDescription(BookFormat format) {
  return switch (format) {
    BookFormat.pdf => 'PDF документ',
    BookFormat.djvu => 'DjVu документ',
    _ => '${format.name.toUpperCase()} документ',
  };
}

class ImportResult {
  final bool isSuccess;
  final bool isDuplicate;
  final bool needsEncodingSelection;
  final String? title;
  final String? error;
  final String? hash;
  final String? suggestedEncoding;
  final String? existingBookId;

  ImportResult._({
    this.isSuccess = false,
    this.isDuplicate = false,
    this.needsEncodingSelection = false,
    this.title,
    this.error,
    this.hash,
    this.suggestedEncoding,
    this.existingBookId,
  });

  factory ImportResult.success(String title) => ImportResult._(isSuccess: true, title: title);
  factory ImportResult.duplicate(String title, String hash, {String? existingBookId}) =>
      ImportResult._(isDuplicate: true, title: title, hash: hash, existingBookId: existingBookId);
  factory ImportResult.failure(String error) => ImportResult._(error: error);
  factory ImportResult.needsEncoding(String title, String? encoding) => ImportResult._(
    needsEncodingSelection: true,
    title: title,
    suggestedEncoding: encoding,
  );
}

class ImportBatchResult {
  final String directory;
  final List<ImportFileResult> fileResults;
  final String? error;
  final bool circuitBroken;

  ImportBatchResult({
    required this.directory,
    List<ImportResult>? results,
    List<ImportFileResult>? fileResults,
    this.error,
    this.circuitBroken = false,
  }) : fileResults =
           fileResults ??
           [
             for (final result in results ?? const <ImportResult>[])
               ImportFileResult(path: '', sizeBytes: null, result: result),
           ];

  List<ImportResult> get results => fileResults.map((item) => item.result).toList();

  int get successCount => results.where((r) => r.isSuccess).length;
  int get duplicateCount => results.where((r) => r.isDuplicate).length;
  int get failureCount =>
      results.where((r) => !r.isSuccess && !r.isDuplicate && !r.needsEncodingSelection).length;

  List<ImportFileResult> get failures => fileResults
      .where(
        (item) =>
            !item.result.isSuccess &&
            !item.result.isDuplicate &&
            !item.result.needsEncodingSelection,
      )
      .toList();
}

class ImportFileResult {
  final String path;
  final int? sizeBytes;
  final ImportResult result;

  const ImportFileResult({
    required this.path,
    required this.sizeBytes,
    required this.result,
  });
}
