import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../reader/data/parsers/book_parser.dart';
import '../../reader/data/parsers/epub_parser.dart';
import '../../reader/data/parsers/fb2_parser.dart';

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final database = ref.watch(databaseProvider);
  return BookImportService(database);
});

class BookImportService {
  final AppDatabase _database;

  BookImportService(this._database);

  final Map<String, BookParser> _parsers = {
    'fb2': Fb2Parser(),
    'epub': EpubParser(),
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
      final book = await parser.parse(bytes, fileName: filePath.split('/').last);

      final booksDir = await _booksDirectory;
      final targetPath = '$booksDir/${book.id}.$ext';
      await file.copy(targetPath);

      await _database
          .into(_database.savedBooks)
          .insertOnConflictUpdate(
            SavedBooksCompanion.insert(
              id: book.id,
              title: book.title,
              authorIds: Value(_encodeList(book.authors)),
              description: Value(book.description),
              coverUrl: Value(book.coverUrl),
              sourceUrl: Value(filePath),
              contentHash: Value(contentHash),
              fileSize: Value(fileSize),
              filePath: Value(targetPath),
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
              targetPath: Value(targetPath),
              status: DownloadStatusDb.completed,
            ),
          );

      return ImportResult.success(book.title);
    } catch (e) {
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

  Future<String> get _booksDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir.path;
  }

  String _encodeList(List<String> items) {
    return '[${items.map((i) => '"${i.replaceAll('"', r'\"')}"').join(',')}]';
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
