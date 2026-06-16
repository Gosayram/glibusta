import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';

void main() {
  group('ImportResult', () {
    test('success creates result with title', () {
      final r = ImportResult.success('Test Book');
      expect(r.isSuccess, isTrue);
      expect(r.isDuplicate, isFalse);
      expect(r.needsEncodingSelection, isFalse);
      expect(r.title, 'Test Book');
      expect(r.error, isNull);
      expect(r.hash, isNull);
    });

    test('duplicate creates result with hash', () {
      final r = ImportResult.duplicate('Book', 'abc123');
      expect(r.isDuplicate, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.title, 'Book');
      expect(r.hash, 'abc123');
      expect(r.error, isNull);
    });

    test('failure creates result with error', () {
      final r = ImportResult.failure('file not found');
      expect(r.isSuccess, isFalse);
      expect(r.isDuplicate, isFalse);
      expect(r.needsEncodingSelection, isFalse);
      expect(r.error, 'file not found');
      expect(r.title, isNull);
    });

    test('needsEncoding creates result with encoding', () {
      final r = ImportResult.needsEncoding('Book Title', 'windows-1251');
      expect(r.needsEncodingSelection, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.title, 'Book Title');
      expect(r.suggestedEncoding, 'windows-1251');
    });

    test('needsEncoding with null encoding', () {
      final r = ImportResult.needsEncoding('Book', null);
      expect(r.suggestedEncoding, isNull);
      expect(r.needsEncodingSelection, isTrue);
    });

    test('failure result with various messages', () {
      expect(ImportResult.failure('corrupt').error, 'corrupt');
      expect(ImportResult.failure('no parser').error, 'no parser');
      expect(ImportResult.failure('').error, '');
    });
  });

  group('ImportBatchResult', () {
    test('counts successes, duplicates, failures', () {
      final batch = ImportBatchResult(
        directory: '/books',
        results: [
          ImportResult.success('A'),
          ImportResult.success('B'),
          ImportResult.duplicate('C', 'hash'),
          ImportResult.failure('error'),
          ImportResult.success('D'),
        ],
      );
      expect(batch.successCount, 3);
      expect(batch.duplicateCount, 1);
      expect(batch.failureCount, 1);
    });

    test('empty results all zero', () {
      final batch = ImportBatchResult(directory: '/x', results: []);
      expect(batch.successCount, 0);
      expect(batch.duplicateCount, 0);
      expect(batch.failureCount, 0);
    });

    test('all duplicates', () {
      final batch = ImportBatchResult(
        directory: '/x',
        results: [
          ImportResult.duplicate('A', 'h1'),
          ImportResult.duplicate('B', 'h2'),
        ],
      );
      expect(batch.successCount, 0);
      expect(batch.duplicateCount, 2);
      expect(batch.failureCount, 0);
    });

    test('error field stored', () {
      final batch = ImportBatchResult(
        directory: '/x',
        results: [],
        error: 'dir not found',
      );
      expect(batch.error, 'dir not found');
    });

    test('directory field stored', () {
      final batch = ImportBatchResult(directory: '/my/books', results: []);
      expect(batch.directory, '/my/books');
    });

    test('fileResults preserve path, size, and result', () {
      final batch = ImportBatchResult(
        directory: '/books',
        fileResults: [
          ImportFileResult(
            path: '/books/a.fb2',
            sizeBytes: 1024,
            result: ImportResult.success('A'),
          ),
          ImportFileResult(
            path: '/books/b.fb2',
            sizeBytes: 2048,
            result: ImportResult.failure('bad file'),
          ),
        ],
      );

      expect(batch.results.length, 2);
      expect(batch.successCount, 1);
      expect(batch.failureCount, 1);
      expect(batch.failures.single.path, '/books/b.fb2');
      expect(batch.failures.single.sizeBytes, 2048);
      expect(batch.failures.single.result.error, 'bad file');
    });

    test('legacy results constructor still creates file results', () {
      final batch = ImportBatchResult(
        directory: '/books',
        results: [ImportResult.success('A')],
      );

      expect(batch.fileResults.single.path, '');
      expect(batch.fileResults.single.sizeBytes, isNull);
      expect(batch.fileResults.single.result.title, 'A');
    });
  });
}
