import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/core/storage/external_book_file.dart';
import 'package:glibusta/core/storage/storage_bridge.dart';
import 'package:glibusta/features/library/data/book_import_service.dart';
import 'package:glibusta/features/library/data/cover_extraction_service.dart';
import 'package:glibusta/features/library/data/inspectors/book_inspection_result.dart';
import 'package:glibusta/features/reader/data/parsers/book_parser.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/data/parsers/parser_registry.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  late AppDatabase db;
  late BookImportService service;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('import_test_');
    final storage = _TestAppFileStorage(tempDir);
    service = BookImportService(db, storage, CoverExtractionService(storage));
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('importFile', () {
    test('uses the path parser without loading a normal import into Dart memory', () async {
      final parser = _RecordingParser();
      service = BookImportService(
        db,
        _TestAppFileStorage(tempDir),
        CoverExtractionService(_TestAppFileStorage(tempDir)),
        parserRegistry: BookParserRegistry([parser]),
      );
      final file = File('${tempDir.path}/path_based.epub');
      await file.writeAsBytes(List<int>.filled(200, 1));

      final result = await service.importFile(file.path);

      expect(result.isSuccess, isTrue);
      expect(parser.parseFileCalls, 1);
      expect(parser.parseCalls, 0);
    });

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

  group('concurrent imports', () {
    test('shares the first result for simultaneous imports of one file', () async {
      final file = File('${tempDir.path}/document.pdf');
      await file.writeAsBytes(List<int>.filled(200, 1));
      const hash = 'same-document-hash';
      final inspection = BookFileInspectionResult(
        path: file.path,
        format: BookFormat.pdf,
        decision: ImportDecision.importAsDocument,
        hash: hash,
        title: 'Document',
      );

      final results = await Future.wait([
        service.importFromInspection(inspection),
        service.importFromInspection(inspection),
      ]);

      expect(results, everyElement(isA<ImportResult>()));
      expect(results.map((result) => result.isSuccess), everyElement(isTrue));
      expect(results.first.title, results.last.title);
    });

    test('coalesces identical content imported from different paths', () async {
      final parseStarted = Completer<void>();
      final allowParsing = Completer<void>();
      final parser = _RecordingParser(
        parseStarted: parseStarted,
        parseFileGate: allowParsing.future,
      );
      final storage = _TestAppFileStorage(tempDir);
      service = BookImportService(
        db,
        storage,
        CoverExtractionService(storage),
        parserRegistry: BookParserRegistry([parser]),
      );
      final firstFile = File('${tempDir.path}/first.epub');
      final secondFile = File('${tempDir.path}/second.epub');
      final contents = List<int>.filled(200, 1);
      await firstFile.writeAsBytes(contents);
      await secondFile.writeAsBytes(contents);

      final firstImport = service.importFile(firstFile.path);
      await parseStarted.future;
      final secondImport = service.importFile(secondFile.path);

      // Let the second file reach the content lock while the first parser is
      // still blocked. Releasing immediately makes this race test depend on
      // the scheduler rather than the lock behaviour it is meant to cover.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(parser.parseFileCalls, 1);
      allowParsing.complete();

      final results = await Future.wait([firstImport, secondImport]);

      expect(results.map((result) => result.isSuccess), everyElement(isTrue));
      expect(parser.parseFileCalls, 1);
    });

    test('coalesces identical content imported from different external URIs', () async {
      final parseStarted = Completer<void>();
      final allowParsing = Completer<void>();
      final parser = _RecordingParser(
        parseStarted: parseStarted,
        parseFileGate: allowParsing.future,
      );
      final storage = _TestAppFileStorage(tempDir);
      service = BookImportService(
        db,
        storage,
        CoverExtractionService(storage),
        parserRegistry: BookParserRegistry([parser]),
      );
      final firstCacheFile = File('${tempDir.path}/external_first.epub');
      final secondCacheFile = File('${tempDir.path}/external_second.epub');
      final contents = List<int>.filled(200, 1);
      await firstCacheFile.writeAsBytes(contents);
      await secondCacheFile.writeAsBytes(contents);
      final bridge = _QueuedStorageBridge([firstCacheFile.path, secondCacheFile.path]);
      const firstExternal = ExternalBookFile(
        uri: 'content://books/first',
        name: 'first.epub',
        size: 200,
        extension: 'epub',
      );
      const secondExternal = ExternalBookFile(
        uri: 'content://books/second',
        name: 'second.epub',
        size: 200,
        extension: 'epub',
      );

      final firstImport = service.importFromExternal(firstExternal, bridge: bridge);
      await parseStarted.future;
      final secondImport = service.importFromExternal(secondExternal, bridge: bridge);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(parser.parseFileCalls, 1);
      expect(await secondCacheFile.exists(), isFalse);
      allowParsing.complete();

      final results = await Future.wait([firstImport, secondImport]);
      expect(results.map((result) => result.isSuccess), everyElement(isTrue));
      expect(bridge.copyCalls, 2);
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

final class _RecordingParser implements BookParser {
  _RecordingParser({this.parseStarted, this.parseFileGate});

  int parseCalls = 0;
  int parseFileCalls = 0;
  final Completer<void>? parseStarted;
  final Future<void>? parseFileGate;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    parseCalls++;
    return const NormalizedBook(id: 'bytes', title: 'Bytes', authors: []);
  }

  @override
  Future<NormalizedBook> parseFile(String filePath, {String? forcedEncoding}) async {
    parseFileCalls++;
    if (parseStarted case final parseStarted? when !parseStarted.isCompleted) {
      parseStarted.complete();
    }
    await parseFileGate;
    return const NormalizedBook(id: 'path', title: 'Path', authors: []);
  }

  @override
  bool supports(BookFormat format) => format == BookFormat.epub;
}

final class _TestAppFileStorage implements AppFileStorage {
  const _TestAppFileStorage(this.root);

  final Directory root;

  Future<Directory> _directory(String name) async {
    final directory = Directory('${root.path}/$name');
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> bookFile(String bookId, BookFormat format) async {
    final directory = await booksDir();
    return File('${directory.path}/$bookId.${format.name}');
  }

  @override
  Future<File> downloadFile(String bookId, BookFormat format) async {
    final directory = await downloadsDir();
    return File('${directory.path}/$bookId.${format.name}');
  }

  @override
  Future<Directory> booksDir() => _directory('books');

  @override
  Future<Directory> downloadsDir() => _directory('downloads');

  @override
  Future<Directory> cacheDir() => _directory('cache');

  @override
  Future<Directory> catalogCoversDir() => _directory('catalog_covers');

  @override
  Future<File> coverFile(String bookId) async {
    final directory = await coversDir();
    return File('${directory.path}/$bookId.jpg');
  }

  @override
  Future<Directory> coversDir() => _directory('covers');

  @override
  Future<Directory> dbDir() => _directory('db');

  @override
  Future<Directory> tempDir() => _directory('temp');
}

final class _QueuedStorageBridge implements StorageBridge {
  _QueuedStorageBridge(this._paths);

  final List<String> _paths;
  int copyCalls = 0;

  @override
  Future<String?> copyToCache(String fileUri) async {
    final path = _paths[copyCalls];
    copyCalls++;
    return path;
  }

  @override
  Future<List<ExternalBookFile>> scanBooks(String folderUri) async => const [];

  @override
  Future<int> countBooks(String folderUri) async => 0;

  @override
  Future<String?> pickFolder() async => null;

  @override
  Future<List<String>> getPersistedUris() async => const [];

  @override
  Future<bool> forgetUri(String uri) async => true;
}
