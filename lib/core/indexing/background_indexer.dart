import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../events/app_events.dart';
import '../logging/app_logger.dart';
import '../services/file_integrity_service.dart';

class IndexingResult {
  const IndexingResult({
    this.booksIndexed = 0,
    this.duplicatesFound = 0,
    this.errorsCount = 0,
    this.totalSizeBytes = 0,
    this.durationMs = 0,
    this.errors = const [],
  });

  final int booksIndexed;
  final int duplicatesFound;
  final int errorsCount;
  final int totalSizeBytes;
  final int durationMs;
  final List<String> errors;
}

class BackgroundIndexer {
  BackgroundIndexer(this._db, this._logger, this._eventBus);
  final AppDatabase _db;
  final AppLogger _logger;
  final EventBus _eventBus;

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  final _progressController = StreamController<double>.broadcast();
  Stream<double> get progress => _progressController.stream;

  Future<IndexingResult> runFullIndex(String libraryPath) async {
    if (_isRunning) {
      _logger.warning('Indexer already running', name: 'Indexer');
      return const IndexingResult();
    }

    _isRunning = true;
    final sw = Stopwatch()..start();
    _logger.info('Starting full index...', name: 'Indexer');

    int indexed = 0;
    int duplicates = 0;
    int errors = 0;
    int totalSize = 0;
    final errorMessages = <String>[];

    try {
      final books = await _db.select(_db.savedBooks).get();
      final total = books.length;

      for (var i = 0; i < total; i++) {
        final book = books[i];
        try {
          final file = File(book.filePath);
          if (await file.exists()) {
            final stat = await file.stat();
            totalSize += stat.size;

            if (book.contentHash == null || book.contentHash!.isEmpty) {
              await _reindexBook(book);
            }
            indexed++;
          } else {
            _logger.warning('Book file missing: ${book.filePath}', name: 'Indexer');
          }
        } on Object catch (e) {
          errors++;
          errorMessages.add('${book.id}: $e');
          _logger.warning('Index error for ${book.id}: $e', name: 'Indexer');
        }

        if (i % 10 == 0) {
          _progressController.add(i / total);
        }
      }

      duplicates = await _findDuplicates();
    } on Object catch (e) {
      _logger.severe('Full index failed: $e', name: 'Indexer');
      errors++;
      errorMessages.add('Full index: $e');
    } finally {
      sw.stop();
      _isRunning = false;
      _progressController.add(1.0);
    }

    final result = IndexingResult(
      booksIndexed: indexed,
      duplicatesFound: duplicates,
      errorsCount: errors,
      totalSizeBytes: totalSize,
      durationMs: sw.elapsedMilliseconds,
      errors: errorMessages,
    );

    _eventBus.fire(
      IndexingCompletedEvent(
        booksIndexed: indexed,
        duplicatesFound: duplicates,
        durationMs: sw.elapsedMilliseconds,
      ),
    );

    _logger.info(
      'Index complete: $indexed books, $duplicates duplicates, $errors errors (${sw.elapsedMilliseconds}ms)',
      name: 'Indexer',
    );

    return result;
  }

  Future<void> indexNewBook(String bookId) async {
    try {
      final book =
          await (_db.select(_db.savedBooks)
                ..where((b) => b.id.equals(bookId))
                ..limit(1))
              .getSingleOrNull();

      if (book != null) {
        await _reindexBook(book);
      }
    } on Object catch (e) {
      _logger.warning('Failed to index book $bookId: $e', name: 'Indexer');
    }
  }

  Future<void> _reindexBook(SavedBook book) async {
    try {
      final file = File(book.filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final hash = await FileIntegrityService(_db, _logger).computeHashBytes(bytes);
        await (_db.update(
          _db.savedBooks,
        )..where((b) => b.id.equals(book.id))).write(SavedBooksCompanion(contentHash: Value(hash)));
      }
    } on Object catch (e) {
      _logger.warning('Reindex failed for ${book.id}: $e', name: 'Indexer');
    }
  }

  Future<int> _findDuplicates() async {
    final books = await _db.select(_db.savedBooks).get();
    final hashGroups = <String, List<SavedBook>>{};

    for (final book in books) {
      if (book.contentHash != null && book.contentHash!.isNotEmpty) {
        hashGroups.putIfAbsent(book.contentHash!, () => []).add(book);
      }
    }

    int duplicateCount = 0;
    for (final group in hashGroups.values) {
      if (group.length > 1) {
        duplicateCount += group.length - 1;
      }
    }

    return duplicateCount;
  }

  Future<int> calculateLibrarySize(String libraryPath) async {
    int totalSize = 0;
    try {
      final dir = Directory(libraryPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    } on Object catch (_) {}
    return totalSize;
  }

  void cancel() {
    _isRunning = false;
  }

  void dispose() {
    unawaited(_progressController.close());
  }
}

// --- Riverpod providers ---

final backgroundIndexerProvider = Provider<BackgroundIndexer>((ref) {
  throw StateError(
    'backgroundIndexerProvider must be overridden at startup with a configured BackgroundIndexer instance.',
  );
});
