import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/library/data/cover_extraction_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class _FakeAppFileStorage implements AppFileStorage {
  final String baseDir;
  _FakeAppFileStorage(this.baseDir);

  @override
  Future<File> bookFile(String bookId, dynamic format) async =>
      File(p.join(baseDir, 'books', '$bookId.${format.toString().split('.').last}'));

  @override
  Future<File> downloadFile(String bookId, dynamic format) async =>
      File(p.join(baseDir, 'downloads', '$bookId.${format.toString().split('.').last}'));

  @override
  Future<File> coverFile(String bookId) async => File(p.join(baseDir, 'covers', '$bookId.jpg'));

  @override
  Future<Directory> booksDir() async {
    final dir = Directory(p.join(baseDir, 'books'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> downloadsDir() async {
    final dir = Directory(p.join(baseDir, 'downloads'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> coversDir() async {
    final dir = Directory(p.join(baseDir, 'covers'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> cacheDir() async {
    final dir = Directory(p.join(baseDir, 'cache'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> tempDir() async {
    final dir = Directory(p.join(baseDir, 'temp'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> catalogCoversDir() async {
    final dir = Directory(p.join(baseDir, 'catalog_covers'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Directory> dbDir() async {
    final dir = Directory(p.join(baseDir, 'db'));
    await dir.create(recursive: true);
    return dir;
  }
}

void main() {
  late CoverExtractionService service;
  late _FakeAppFileStorage storage;
  late Directory tempDir;
  late Uint8List validJpegBytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cover_test_');
    storage = _FakeAppFileStorage(tempDir.path);
    service = CoverExtractionService(storage);
    final red = img.Image(width: 10, height: 10);
    img.fill(red, color: img.ColorRgb8(255, 0, 0));
    validJpegBytes = Uint8List.fromList(img.encodeJpg(red, quality: 85));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('extractAndSaveCover with pre-extracted coverBytes', () {
    test('uses coverBytes when provided for epub format', () async {
      final fakeFile = File('${tempDir.path}/dummy.epub');
      await fakeFile.writeAsBytes([0]);

      final result = await service.extractAndSaveCover(
        bookId: 'test_epub_cover',
        filePath: fakeFile.path,
        format: 'epub',
        coverBytes: validJpegBytes,
      );

      expect(result, isNotNull);
      expect(result, contains('test_epub_cover.jpg'));
      final coverFile = File(result!);
      expect(await coverFile.exists(), isTrue);
    });

    test('uses coverBytes when provided for mobi format', () async {
      final fakeFile = File('${tempDir.path}/dummy.mobi');
      await fakeFile.writeAsBytes([0]);

      final result = await service.extractAndSaveCover(
        bookId: 'test_mobi_cover',
        filePath: fakeFile.path,
        format: 'mobi',
        coverBytes: validJpegBytes,
      );

      expect(result, isNotNull);
      expect(result, contains('test_mobi_cover.jpg'));
    });

    test('falls back to file extraction when coverBytes is null', () async {
      final fakeFile = File('${tempDir.path}/empty.epub');
      await fakeFile.writeAsBytes([0]);

      final result = await service.extractAndSaveCover(
        bookId: 'test_no_cover',
        filePath: fakeFile.path,
        format: 'epub',
      );

      expect(result, isNull);
    });

    test('returns null for invalid coverBytes', () async {
      final fakeFile = File('${tempDir.path}/dummy.mobi');
      await fakeFile.writeAsBytes([0]);

      final result = await service.extractAndSaveCover(
        bookId: 'test_invalid_cover',
        filePath: fakeFile.path,
        format: 'mobi',
        coverBytes: Uint8List.fromList([0, 1, 2, 3]),
      );

      expect(result, isNull);
    });
  });
}
