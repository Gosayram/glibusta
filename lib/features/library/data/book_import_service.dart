import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../core/storage/external_book_file.dart';
import '../../../core/storage/storage_bridge.dart';
import '../../../shared/models/book.dart';
import '../../reader/data/parsers/book_parser.dart';
import '../../reader/data/parsers/epub_parser.dart';
import '../../reader/data/parsers/fb2_parser.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../../reader/data/parsers/txt_parser.dart';
import 'inspectors/book_inspection_result.dart';

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final database = ref.watch(databaseProvider);
  return BookImportService(database);
});

class BookImportService {
  final AppDatabase _database;
  final AppFileStorage _storage;

  BookImportService(this._database) : _storage = AppFileStorageImpl();

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

      return ImportResult.success(book.title);
    } on Object catch (e) {
      return ImportResult.failure('Ошибка при импорте: $e');
    }
  }

  /// Import a book from an external SAF URI into the app library.
  Future<ImportResult> importFromExternal(
    ExternalBookFile external, {
    required StorageBridge bridge,
  }) async {
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

      return ImportResult.success(book.title);
    } on Object catch (e) {
      return ImportResult.failure('Ошибка при импорте из внешней папки: $e');
    }
  }

  Future<ImportBatchResult> importDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
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

    return ImportBatchResult(directory: dirPath, results: results);
  }

  Future<SavedBook?> _findByHash(String hash) async {
    final rows = await (_database.select(
      _database.savedBooks,
    )..where((t) => t.contentHash.equals(hash))).get();
    return rows.isNotEmpty ? rows.first : null;
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
  int get failureCount => results.where((r) => !r.isSuccess && !r.isDuplicate).length;
}
