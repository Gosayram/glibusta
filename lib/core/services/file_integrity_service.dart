import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';

enum IntegrityStatus { valid, corrupted, missing, unknown }

class IntegrityResult {
  const IntegrityResult({
    required this.status,
    required this.expectedHash,
    this.actualHash,
    this.message,
  });

  final IntegrityStatus status;
  final String expectedHash;
  final String? actualHash;
  final String? message;

  bool get isValid => status == IntegrityStatus.valid;
}

class FileIntegrityService {
  FileIntegrityService(this._db, this._logger);
  final AppDatabase _db;
  final AppLogger _logger;

  Future<String> computeHash(File file) async {
    final digest = await sha256.bind(file.openRead()).last;
    return digest.toString();
  }

  Future<String> computeHashBytes(Uint8List bytes) async {
    return sha256.convert(bytes).toString();
  }

  Future<IntegrityResult> verifyBook(String bookId) async {
    final book =
        await (_db.select(_db.savedBooks)
              ..where((b) => b.id.equals(bookId))
              ..limit(1))
            .getSingleOrNull();

    if (book == null) {
      return const IntegrityResult(
        status: IntegrityStatus.unknown,
        expectedHash: '',
        message: 'Book not found in database',
      );
    }

    final file = File(book.filePath);
    if (!await file.exists()) {
      return IntegrityResult(
        status: IntegrityStatus.missing,
        expectedHash: book.contentHash ?? '',
        message: 'File not found at ${book.filePath}',
      );
    }

    if (book.contentHash == null || book.contentHash!.isEmpty) {
      return const IntegrityResult(
        status: IntegrityStatus.unknown,
        expectedHash: '',
        message: 'No hash stored for this book',
      );
    }

    final actualHash = await computeHash(file);
    if (actualHash == book.contentHash) {
      return IntegrityResult(
        status: IntegrityStatus.valid,
        expectedHash: book.contentHash!,
        actualHash: actualHash,
      );
    }

    return IntegrityResult(
      status: IntegrityStatus.corrupted,
      expectedHash: book.contentHash!,
      actualHash: actualHash,
      message: 'Hash mismatch: expected ${book.contentHash}, got $actualHash',
    );
  }

  Future<void> verifyAndRepair(String bookId) async {
    final result = await verifyBook(bookId);
    if (!result.isValid) {
      _logger.warning(
        'Book integrity check failed: $bookId - ${result.message}',
        name: 'FileIntegrity',
      );
    }
  }

  Future<List<String>> verifyAll() async {
    final books = await _db.select(_db.savedBooks).get();
    final corrupted = <String>[];
    for (final book in books) {
      final result = await verifyBook(book.id);
      if (!result.isValid) {
        corrupted.add(book.id);
      }
    }
    return corrupted;
  }

  Future<void> updateHash(String bookId, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final hash = await computeHash(file);
    await (_db.update(
      _db.savedBooks,
    )..where((b) => b.id.equals(bookId))).write(SavedBooksCompanion(contentHash: Value(hash)));
  }

  Future<IntegrityResult> verifyDownload(
    String filePath, {
    String? expectedHash,
    int? expectedSize,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const IntegrityResult(
        status: IntegrityStatus.missing,
        expectedHash: '',
        message: 'Downloaded file not found',
      );
    }

    final stat = await file.stat();
    if (expectedSize != null && stat.size != expectedSize) {
      return IntegrityResult(
        status: IntegrityStatus.corrupted,
        expectedHash: expectedHash ?? '',
        message: 'Size mismatch: expected $expectedSize, got ${stat.size}',
      );
    }

    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actualHash = await computeHash(file);
      if (actualHash != expectedHash) {
        return IntegrityResult(
          status: IntegrityStatus.corrupted,
          expectedHash: expectedHash,
          actualHash: actualHash,
          message: 'Hash mismatch after download',
        );
      }
    }

    return IntegrityResult(
      status: IntegrityStatus.valid,
      expectedHash: expectedHash ?? '',
      actualHash: await computeHash(file),
    );
  }
}

// --- Riverpod providers ---

final fileIntegrityServiceProvider = Provider<FileIntegrityService>((ref) {
  throw StateError(
    'fileIntegrityServiceProvider must be overridden at startup with a configured FileIntegrityService instance.',
  );
});
