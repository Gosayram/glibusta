import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/encoding/encoding_detection.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../shared/models/book.dart';
import '../../reader/data/parsers/book_parser.dart';
import '../../reader/data/parsers/epub_parser.dart';
import '../../reader/data/parsers/fb2_parser.dart';
import '../../reader/data/parsers/txt_parser.dart';

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final database = ref.watch(databaseProvider);
  return BookImportService(database);
});

class BookImportService {
  final AppDatabase _database;
  final AppFileStorage _storage;
  final BookEncodingDetector _detector;

  BookImportService(this._database)
    : _storage = AppFileStorageImpl(),
      _detector = BookEncodingDetector();

  final Map<String, BookParser> _parsers = {
    'fb2': Fb2Parser(),
    'epub': EpubParser(),
    'txt': TxtBookParser(),
  };

  static const _supportedExtensions = ['fb2', 'epub', 'txt'];

  Future<ImportResult> importFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult.failure('Файл не найден: $filePath');
    }

    final ext = filePath.split('.').last.toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      return ImportResult.failure('Формат не поддерживается: .$ext');
    }

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
      // Detect encoding before parsing
      final encodingResult = await _detector.detect(
        bytes,
        fileName: filePath.split('/').last,
      );

      final book = await parser.parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: encodingResult.encoding,
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
              detectedEncoding: Value(encodingResult.encoding),
              encodingConfidence: Value(encodingResult.confidence),
              encodingSource: Value(encodingResult.source.name),
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
  final String? title;
  final String? error;
  final String? hash;

  ImportResult._({
    this.isSuccess = false,
    this.isDuplicate = false,
    this.title,
    this.error,
    this.hash,
  });

  factory ImportResult.success(String title) => ImportResult._(isSuccess: true, title: title);
  factory ImportResult.duplicate(String title, String hash) =>
      ImportResult._(isDuplicate: true, title: title, hash: hash);
  factory ImportResult.failure(String error) => ImportResult._(error: error);
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
