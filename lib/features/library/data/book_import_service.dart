import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/formats/book_file_size_policy.dart';
import '../../../core/formats/format_capability.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../core/storage/external_book_file.dart';
import '../../../core/storage/storage_bridge.dart';
import '../../../core/utils/fire_and_log.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../../reader/data/parsers/parser_registry.dart';
import '../data/cover_extraction_service.dart';
import 'inspectors/book_inspection_result.dart';

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final database = ref.watch(databaseProvider);
  return BookImportService(database);
});

class BookImportService {
  final AppDatabase _database;
  final AppFileStorage _storage;
  final CoverExtractionService _coverService;
  final _logger = AppLogger();

  BookImportService(this._database)
    : _storage = AppFileStorageImpl(),
      _coverService = CoverExtractionService();

  final _registry = BookParserRegistry.defaultInstance;

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

    if (inspection.decision == ImportDecision.importAsDocument) {
      return _doDocumentImport(inspection);
    }

    return _doImport(inspection.path, forcedEncoding: inspection.encoding);
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
  }

  Future<ImportResult> _doImport(String filePath, {String? forcedEncoding}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult.failure('Файл не найден: $filePath');
    }

    final ext = filePath.split('.').last.toLowerCase();
    final format = bookFormatForImportExtension(ext);
    final size = await file.length();
    if (isBookFileTooLarge(format, size)) {
      return ImportResult.failure(bookFileTooLargeMessage(format, size));
    }
    final bytes = await file.readAsBytes();
    final contentHash = sha256.convert(bytes).toString();
    final fileSize = bytes.length;

    final existing = await _findByHash(contentHash);
    if (existing != null) {
      _logger.info(
        'Duplicate detected: ${existing.title} (${contentHash.substring(0, 8)})',
        name: 'Import',
      );
      return ImportResult.duplicate(existing.title, contentHash, existingBookId: existing.id);
    }

    final parser =
        _registry.parserForExtension(ext) ??
        (ext == 'zip' ? _registry.parserFor(BookFormat.fb2) : null);
    if (parser == null) {
      return ImportResult.failure(_unsupportedReaderMessage(ext));
    }

    final bookId = contentHash;
    try {
      final book = await parser.parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: forcedEncoding,
      );

      Uint8List? coverBytes;
      if (book.metadata != null) {
        coverBytes = book.metadata!['mobiCoverBytes'] as Uint8List?;
      }

      final targetFile = await _storage.bookFile(
        bookId,
        format,
      );
      await targetFile.parent.create(recursive: true);
      await file.copy(targetFile.path);

      final authorIds = <String>[];
      for (final authorName in book.authors) {
        final authorId = generateAuthorId(authorName);
        authorIds.add(authorId);
        await _database
            .into(_database.authors)
            .insertOnConflictUpdate(
              AuthorsCompanion.insert(
                id: authorId,
                name: authorName,
              ),
            );
      }

      await _database.transaction(() async {
        await _database
            .into(_database.savedBooks)
            .insertOnConflictUpdate(
              SavedBooksCompanion.insert(
                id: bookId,
                title: book.title,
                authorIds: Value(authorIds),
                description: Value(book.description),
                coverUrl: Value(book.coverUrl),
                sourceUrl: Value(filePath),
                contentHash: Value(contentHash),
                fileSize: Value(fileSize),
                filePath: Value(targetFile.path),
                detectedEncoding: Value(forcedEncoding),
                encodingSource: forcedEncoding != null
                    ? const Value('manual')
                    : const Value.absent(),
                userForcedEncoding: Value(forcedEncoding),
              ),
            );

        await _database
            .into(_database.downloads)
            .insertOnConflictUpdate(
              DownloadsCompanion.insert(
                id: bookId,
                bookId: bookId,
                bookTitle: Value(book.title),
                format: formatToDbString(formatForExtension(ext)),
                sourceUrl: filePath,
                targetPath: Value(targetFile.path),
                status: DownloadStatusDb.completed,
              ),
            );
      });

      // Background cover extraction — don't block import
      fireAndLog(
        () => _extractCoverBackground(bookId, targetFile.path, ext, coverBytes: coverBytes),
        name: 'Import',
        context: 'Cover extraction for $bookId',
      );

      return ImportResult.success(book.title);
    } on Object catch (e) {
      _logger.warning('Import failed for $filePath: $e', name: 'Import', error: e);
      try {
        final targetFile = await _storage.bookFile(
          bookId,
          format,
        );
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await _deletePartialImportRows(bookId);
      } on Object catch (_) {
        // Best-effort cleanup: ignore if target file path can't be resolved
      }
      return ImportResult.failure(_friendlyImportError(e));
    }
  }

  Future<ImportResult> _doDocumentImport(BookFileInspectionResult inspection) async {
    final file = File(inspection.path);
    if (!await file.exists()) {
      return ImportResult.failure('Файл не найден: ${inspection.path}');
    }

    final ext = inspection.path.split('.').last.toLowerCase();
    final format = bookFormatForImportExtension(ext);
    if (format == BookFormat.unknown) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }
    final size = await file.length();
    if (isBookFileTooLarge(format, size)) {
      return ImportResult.failure(bookFileTooLargeMessage(format, size));
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return ImportResult.failure('Файл пуст: ${inspection.path}');
    }

    final contentHash = inspection.hash.isNotEmpty
        ? inspection.hash
        : sha256.convert(bytes).toString();
    final existing = await _findByHash(contentHash);
    if (existing != null) {
      return ImportResult.duplicate(existing.title, contentHash, existingBookId: existing.id);
    }

    final fileName = inspection.path.split('/').last;
    final title = inspection.title ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final bookId = contentHash;
    final targetFile = await _storage.bookFile(bookId, format);
    try {
      await targetFile.parent.create(recursive: true);
      try {
        await file.copy(targetFile.path);
      } on Object catch (e) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await _deletePartialImportRows(bookId);
        return ImportResult.failure(_friendlyImportError(e));
      }

      await _database.transaction(() async {
        await _database
            .into(_database.savedBooks)
            .insertOnConflictUpdate(
              SavedBooksCompanion.insert(
                id: bookId,
                title: title,
                authorIds: const Value([]),
                description: Value(_documentDescription(format)),
                sourceUrl: Value(inspection.path),
                contentHash: Value(contentHash),
                fileSize: Value(bytes.length),
                filePath: Value(targetFile.path),
              ),
            );

        await _database
            .into(_database.downloads)
            .insertOnConflictUpdate(
              DownloadsCompanion.insert(
                id: bookId,
                bookId: bookId,
                bookTitle: Value(title),
                format: format.name,
                sourceUrl: inspection.path,
                targetPath: Value(targetFile.path),
                status: DownloadStatusDb.completed,
              ),
            );
      });

      return ImportResult.success(title);
    } on Object catch (e) {
      _logger.warning(
        'Document import failed for ${inspection.path}: $e',
        name: 'Import',
        error: e,
      );
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await _deletePartialImportRows(bookId);
      return ImportResult.failure(_friendlyImportError(e));
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

    late String bookId;
    File? cacheFile;
    try {
      final cachedPath = await bridge.copyToCache(external.uri);
      if (cachedPath == null) {
        return ImportResult.failure('Не удалось прочитать файл: ${external.name}');
      }
      cacheFile = File(cachedPath);
      if (!await cacheFile.exists() || await cacheFile.length() == 0) {
        await cacheFile.exists().then((_) => _tryDelete(cachedPath));
        return ImportResult.failure('Файл пуст: ${external.name}');
      }

      final fileSize = await cacheFile.length();
      if (isBookFileTooLarge(format, fileSize)) {
        await _tryDelete(cachedPath);
        return ImportResult.failure(bookFileTooLargeMessage(format, fileSize));
      }

      final digest = await sha256.bind(cacheFile.openRead()).first;
      final contentHash = digest.toString();
      bookId = contentHash;
      final existing = await _findByHash(contentHash);
      if (existing != null) {
        await _tryDelete(cachedPath);
        return ImportResult.duplicate(existing.title, contentHash, existingBookId: existing.id);
      }

      final bytes = await cacheFile.readAsBytes();

      if (const FormatCapabilityService().isDocumentOnly(format)) {
        final title = external.name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final documentBookId = contentHash;
        bookId = documentBookId;
        final targetFile = await _storage.bookFile(documentBookId, format);
        await targetFile.parent.create(recursive: true);
        await cacheFile.rename(targetFile.path);

        await _database.transaction(() async {
          await _database
              .into(_database.savedBooks)
              .insertOnConflictUpdate(
                SavedBooksCompanion.insert(
                  id: documentBookId,
                  title: title,
                  authorIds: const Value([]),
                  description: Value(_documentDescription(format)),
                  sourceUrl: Value(external.uri),
                  contentHash: Value(contentHash),
                  fileSize: Value(external.size),
                  filePath: Value(targetFile.path),
                  storageMode: const Value('external'),
                  externalUri: Value(external.uri),
                ),
              );

          await _database
              .into(_database.downloads)
              .insertOnConflictUpdate(
                DownloadsCompanion.insert(
                  id: documentBookId,
                  bookId: documentBookId,
                  bookTitle: Value(title),
                  format: format.name,
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

      final book = await parser.parse(
        bytes,
        fileName: external.name,
      );

      Uint8List? extCoverBytes;
      if (book.metadata != null) {
        extCoverBytes = book.metadata!['mobiCoverBytes'] as Uint8List?;
      }

      final targetFile = await _storage.bookFile(
        bookId,
        format,
      );
      await targetFile.parent.create(recursive: true);
      try {
        await cacheFile.rename(targetFile.path);
      } on Object catch (_) {
        await cacheFile.copy(targetFile.path);
        await _tryDelete(cacheFile.path);
      }

      final extAuthorIds = <String>[];
      for (final authorName in book.authors) {
        final authorId = generateAuthorId(authorName);
        extAuthorIds.add(authorId);
        await _database
            .into(_database.authors)
            .insertOnConflictUpdate(
              AuthorsCompanion.insert(
                id: authorId,
                name: authorName,
              ),
            );
      }

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
                fileSize: Value(external.size),
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
                format: formatToDbString(formatForExtension(ext)),
                sourceUrl: external.uri,
                targetPath: Value(targetFile.path),
                status: DownloadStatusDb.completed,
              ),
            );
      });

      fireAndLog(
        () => _extractCoverBackground(bookId, targetFile.path, ext, coverBytes: extCoverBytes),
        name: 'Import',
        context: 'Cover extraction for $bookId',
      );

      return ImportResult.success(book.title);
    } on Object catch (e) {
      _logger.warning(
        'External import failed for ${external.name}: $e',
        name: 'Import',
        error: e,
      );
      if (cacheFile != null) {
        await _tryDelete(cacheFile.path);
      }
      try {
        final targetFile = await _storage.bookFile(
          bookId,
          bookFormatForImportExtension(ext),
        );
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
  }) async {
    _logger.info('Import directory: $dirPath', name: 'Import');
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      _logger.warning('Directory not found: $dirPath', name: 'Import');
      return ImportBatchResult(directory: dirPath, results: [], error: 'Директория не найдена');
    }

    final fileResults = <ImportFileResult>[];
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (isCancelled != null && isCancelled()) {
          _logger.info('Directory import cancelled', name: 'Import');
          break;
        }
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (importableExtensions.contains(ext)) {
            final size = await entity.length();
            final result = await importFile(entity.path);
            fileResults.add(
              ImportFileResult(path: entity.path, sizeBytes: size, result: result),
            );
            if (!result.isSuccess && !result.isDuplicate && !result.needsEncodingSelection) {
              _logger.warning(
                'Directory import failed for ${entity.path} (${formatBytes(size)}): ${result.error}',
                name: 'Import',
              );
            }
          }
        }
      }
    } on Object catch (e) {
      _logger.warning('Directory scan failed for $dirPath: $e', name: 'Import', error: e);
      return ImportBatchResult(
        directory: dirPath,
        fileResults: fileResults,
        error: _friendlyImportError(e),
      );
    }

    final batch = ImportBatchResult(directory: dirPath, fileResults: fileResults);
    _logger.info(
      'Directory import complete: ${batch.successCount} imported, ${batch.duplicateCount} duplicates, ${batch.failureCount} errors',
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
    } on Object catch (_) {}
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

  ImportBatchResult({
    required this.directory,
    List<ImportResult>? results,
    List<ImportFileResult>? fileResults,
    this.error,
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
