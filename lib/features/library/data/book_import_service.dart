import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../core/storage/external_book_file.dart';
import '../../../core/storage/storage_bridge.dart';
import '../../reader/data/parsers/book_parser.dart';
import '../../reader/data/parsers/epub_parser.dart';
import '../../reader/data/parsers/fb2_parser.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../../reader/data/parsers/txt_parser.dart';
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

  final Map<String, BookParser> _parsers = {
    'fb2': Fb2Parser(),
    'epub': EpubParser(),
    'txt': TxtBookParser(),
  };

  static const _supportedExtensions = ['fb2', 'epub', 'txt'];

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
    if (inspection.decision == ImportDecision.openAsPdf) {
      return ImportResult.failure('PDF открывается отдельным просмотрщиком');
    }
    if (inspection.decision == ImportDecision.needsEncodingSelection) {
      return ImportResult.needsEncoding(
        inspection.title ?? 'Неизвестная кодировка',
        inspection.encoding,
      );
    }

    // importAsBook
    return _doImport(inspection.path, forcedEncoding: inspection.encoding);
  }

  /// Import a file by path (runs full inspection + import).
  Future<ImportResult> importFile(String filePath) async {
    final ext = filePath.split('.').last.toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }
    return _doImport(filePath);
  }

  Future<ImportResult> _doImport(String filePath, {String? forcedEncoding}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult.failure('Файл не найден: $filePath');
    }

    final ext = filePath.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();
    final contentHash = sha256.convert(bytes).toString();
    final fileSize = bytes.length;

    final existing = await _findByHash(contentHash);
    if (existing != null) {
      _logger.info(
        'Duplicate detected: ${existing.title} (${contentHash.substring(0, 8)})',
        name: 'Import',
      );
      return ImportResult.duplicate(existing.title, contentHash);
    }

    final parser = _parsers[ext];
    if (parser == null) {
      return ImportResult.failure('Парсер для .$ext не найден');
    }

    try {
      final book = await parser.parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: forcedEncoding,
      );

      final targetFile = await _storage.bookFile(
        book.id,
        BookFormat.values.firstWhere(
          (f) => f.name == ext,
          orElse: () => BookFormat.epub,
        ),
      );
      await targetFile.parent.create(recursive: true);
      await file.copy(targetFile.path);

      await _database
          .into(_database.savedBooks)
          .insertOnConflictUpdate(
            SavedBooksCompanion.insert(
              id: book.id,
              title: book.title,
              authorIds: Value(book.authors),
              description: Value(book.description),
              coverUrl: Value(book.coverUrl),
              sourceUrl: Value(filePath),
              contentHash: Value(contentHash),
              fileSize: Value(fileSize),
              filePath: Value(targetFile.path),
              detectedEncoding: Value(forcedEncoding),
              encodingSource: forcedEncoding != null ? const Value('manual') : const Value.absent(),
              userForcedEncoding: Value(forcedEncoding),
            ),
          );

      await _database
          .into(_database.downloads)
          .insertOnConflictUpdate(
            DownloadsCompanion.insert(
              id: book.id,
              bookId: book.id,
              bookTitle: Value(book.title),
              format: ext,
              sourceUrl: filePath,
              targetPath: Value(targetFile.path),
              status: DownloadStatusDb.completed,
            ),
          );

      // Background cover extraction — don't block import
      unawaited(_extractCoverBackground(book.id, targetFile.path, ext));

      return ImportResult.success(book.title);
    } on Object catch (e) {
      _logger.warning('Import failed for $filePath: $e', name: 'Import', error: e);
      return ImportResult.failure('Ошибка при импорте: $e');
    }
  }

  /// Import a book from an external SAF URI into the app library.
  Future<ImportResult> importFromExternal(
    ExternalBookFile external, {
    required StorageBridge bridge,
  }) async {
    _logger.info('Import from external: ${external.name} (${external.extension})', name: 'Import');
    final ext = external.extension.toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }

    try {
      final bytes = await bridge.readFile(external.uri);
      if (bytes.isEmpty) {
        return ImportResult.failure('Файл пуст: ${external.name}');
      }

      final contentHash = sha256.convert(bytes).toString();
      final existing = await _findByHash(contentHash);
      if (existing != null) {
        return ImportResult.duplicate(existing.title, contentHash);
      }

      final parser = _parsers[ext];
      if (parser == null) {
        return ImportResult.failure('Парсер для .$ext не найден');
      }

      final book = await parser.parse(
        bytes,
        fileName: external.name,
      );

      final targetFile = await _storage.bookFile(
        book.id,
        BookFormat.values.firstWhere(
          (f) => f.name == ext,
          orElse: () => BookFormat.epub,
        ),
      );
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(bytes, flush: true);

      await _database
          .into(_database.savedBooks)
          .insertOnConflictUpdate(
            SavedBooksCompanion.insert(
              id: book.id,
              title: book.title,
              authorIds: Value(book.authors),
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
              id: book.id,
              bookId: book.id,
              bookTitle: Value(book.title),
              format: ext,
              sourceUrl: external.uri,
              targetPath: Value(targetFile.path),
              status: DownloadStatusDb.completed,
            ),
          );

      unawaited(_extractCoverBackground(book.id, targetFile.path, ext));

      return ImportResult.success(book.title);
    } on Object catch (e) {
      return ImportResult.failure('Ошибка при импорте из внешней папки: $e');
    }
  }

  Future<ImportBatchResult> importDirectory(String dirPath) async {
    _logger.info('Import directory: $dirPath', name: 'Import');
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      _logger.warning('Directory not found: $dirPath', name: 'Import');
      return ImportBatchResult(directory: dirPath, results: [], error: 'Директория не найдена');
    }

    final results = <ImportResult>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          results.add(await importFile(entity.path));
        }
      }
    }

    final batch = ImportBatchResult(directory: dirPath, results: results);
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

  Future<void> _extractCoverBackground(String bookId, String filePath, String format) async {
    try {
      _logger.info('Extracting cover for $bookId', name: 'Import');
      final coverPath = await _coverService.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        format: format,
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

class ImportResult {
  final bool isSuccess;
  final bool isDuplicate;
  final bool needsEncodingSelection;
  final String? title;
  final String? error;
  final String? hash;
  final String? suggestedEncoding;

  ImportResult._({
    this.isSuccess = false,
    this.isDuplicate = false,
    this.needsEncodingSelection = false,
    this.title,
    this.error,
    this.hash,
    this.suggestedEncoding,
  });

  factory ImportResult.success(String title) => ImportResult._(isSuccess: true, title: title);
  factory ImportResult.duplicate(String title, String hash) =>
      ImportResult._(isDuplicate: true, title: title, hash: hash);
  factory ImportResult.failure(String error) => ImportResult._(error: error);
  factory ImportResult.needsEncoding(String title, String? encoding) => ImportResult._(
    needsEncodingSelection: true,
    title: title,
    suggestedEncoding: encoding,
  );
}

class ImportBatchResult {
  final String directory;
  final List<ImportResult> results;
  final String? error;

  ImportBatchResult({required this.directory, required this.results, this.error});

  int get successCount => results.where((r) => r.isSuccess).length;
  int get duplicateCount => results.where((r) => r.isDuplicate).length;
  int get failureCount =>
      results.where((r) => !r.isSuccess && !r.isDuplicate && !r.needsEncodingSelection).length;
}
