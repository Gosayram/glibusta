import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  late AppDatabase db;
  late BookImportService service;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BookImportService(db);
    tempDir = await Directory.systemTemp.createTemp('import_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('importFile', () {
    test('returns failure for unsupported extension', () async {
      final result = await service.importFile('/tmp/test.pdf');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Формат не поддерживается'));
    });

    test('returns failure for nonexistent file', () async {
      final result = await service.importFile('/tmp/nonexistent_book.epub');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('не найден'));
    });

    test('returns failure for file too small', () async {
      final file = File('${tempDir.path}/tiny.epub');
      await file.writeAsBytes(List.filled(10, 0));
      final result = await service.importFile(file.path);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('слишком мал'));
    });
  });

  group('bookFormatForImportExtension', () {
    test('maps fb2.zip imports to fb2 storage format', () {
      expect(bookFormatForImportExtension('zip'), BookFormat.fb2);
      expect(bookFormatForImportExtension('ZIP'), BookFormat.fb2);
    });

    test('maps document imports to document storage formats', () {
      expect(bookFormatForImportExtension('pdf'), BookFormat.pdf);
      expect(bookFormatForImportExtension('djvu'), BookFormat.djvu);
      expect(bookFormatForImportExtension('djv'), BookFormat.djvu);
      expect(bookFormatForImportExtension('rtf'), BookFormat.rtf);
    });
  });

  group('importDirectory', () {
    test('returns error for nonexistent directory', () async {
      final result = await service.importDirectory('/tmp/nonexistent_dir');
      expect(result.results, isEmpty);
      expect(result.error, contains('не найдена'));
    });

    test('imports supported files from directory', () async {
      final bookFile = File('${tempDir.path}/test.epub');
      await bookFile.writeAsBytes(List.filled(200, 0));

      final result = await service.importDirectory(tempDir.path);
      expect(result.results.length, 1);
    });

    test('skips unsupported files', () async {
      final pdfFile = File('${tempDir.path}/test.pdf');
      await pdfFile.writeAsBytes(List.filled(200, 0));

      final result = await service.importDirectory(tempDir.path);
      expect(result.results, isEmpty);
    });
  });

  group('ImportBatchResult', () {
    test('failureCount excludes needsEncodingSelection', () async {
      final batch = ImportBatchResult(
        directory: '/x',
        results: [
          ImportResult.needsEncoding('A', null),
          ImportResult.failure('error'),
        ],
      );
      expect(batch.failureCount, 1);
    });
  });
}
