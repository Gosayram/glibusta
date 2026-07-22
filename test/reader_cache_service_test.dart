import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/data/reader_cache_service.dart';
import 'package:glibusta/shared/models/book.dart';

final class _TestStorage implements AppFileStorage {
  const _TestStorage(this.root);

  final Directory root;

  @override
  Future<File> bookFile(String bookId, BookFormat format) async => File('${root.path}/$bookId');

  @override
  Future<File> downloadFile(String bookId, BookFormat format) async =>
      File('${root.path}/downloads/$bookId.${format.name}');

  @override
  Future<Directory> booksDir() async => root;

  @override
  Future<Directory> downloadsDir() async => Directory('${root.path}/downloads');

  @override
  Future<Directory> cacheDir() async {
    final cache = Directory('${root.path}/cache');
    await cache.create(recursive: true);
    return cache;
  }

  @override
  Future<Directory> catalogCoversDir() async => root;

  @override
  Future<File> coverFile(String bookId) async => File('${root.path}/$bookId.jpg');

  @override
  Future<Directory> coversDir() async => root;

  @override
  Future<Directory> dbDir() async => root;

  @override
  Future<Directory> tempDir() async => root;
}

void main() {
  test('invalidate preserves EPUB images outside the deleted cache directory', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => const CacheSourceFingerprint(
        format: 'epub',
        fileSize: 1,
        fileMtime: 1,
        contentHash: 'hash',
      ),
      storage: _TestStorage(root),
      logger: AppLogger(),
    );
    const book = NormalizedBook(
      id: 'content-hash',
      title: 'Book',
      authors: [],
      chapters: [ReaderChapter(index: 0, title: 'Chapter', blocks: [])],
    );

    await service.putBook('book', book);
    final metadata = await service.getMetadata('book');
    expect(metadata, isNotNull);
    expect(await service.isCacheValid('book', metadata!), isTrue);

    final bookDir = await service.getBookDir('book');
    final image = File('${bookDir.path}/epub_images/cover.jpg');
    await image.parent.create(recursive: true);
    await image.writeAsBytes([1, 2, 3]);

    await service.invalidate('book', preserveImages: true);

    expect(await image.exists(), isTrue);
    expect(await service.getMetadata('book'), isNull);
  });

  test('concurrent chapter writes do not share a temporary file', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => null,
      storage: _TestStorage(root),
      logger: AppLogger(),
    );

    await Future.wait(
      List.generate(
        8,
        (index) => service.putChapter(
          'book',
          ReaderChapter(index: 0, title: 'Chapter $index', blocks: const []),
        ),
      ),
    );

    final chapter = await service.getChapter('book', 0);
    expect(chapter, isNotNull);
    expect(chapter!.title, startsWith('Chapter '));
  });

  test('replaces an existing chapter with the newly written content', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => null,
      storage: _TestStorage(root),
      logger: AppLogger(),
    );

    await service.putChapter(
      'book',
      const ReaderChapter(index: 0, title: 'Old chapter', blocks: []),
    );
    await service.putChapter(
      'book',
      const ReaderChapter(index: 0, title: 'Replacement chapter', blocks: []),
    );

    expect((await service.getChapter('book', 0))?.title, 'Replacement chapter');
  });

  test('removes the temporary file when chapter replacement fails', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => null,
      storage: _TestStorage(root),
      logger: AppLogger(),
    );
    final bookDir = await service.getBookDir('book');
    await Directory('${bookDir.path}/ch_0.json').create();

    await expectLater(
      service.putChapter(
        'book',
        const ReaderChapter(index: 0, title: 'Chapter', blocks: []),
      ),
      throwsA(isA<FileSystemException>()),
    );

    final remainingTemporaryFiles = await bookDir
        .list()
        .where((entity) => entity.path.endsWith('.tmp'))
        .toList();
    expect(remainingTemporaryFiles, isEmpty);
  });

  test('rejects a book ID that could escape the cache directory', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => null,
      storage: _TestStorage(root),
      logger: AppLogger(),
    );

    await expectLater(
      service.putChapter(
        '../outside',
        const ReaderChapter(index: 0, title: 'Chapter', blocks: []),
      ),
      throwsArgumentError,
    );
    expect(await Directory('${root.path}/outside').exists(), isFalse);
  });

  test('rejects a manifest with duplicate chapter indices', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => const CacheSourceFingerprint(
        format: 'txt',
        fileSize: 1,
        fileMtime: 1,
        contentHash: 'hash',
      ),
      storage: _TestStorage(root),
      logger: AppLogger(),
    );
    const book = NormalizedBook(
      id: 'content-hash',
      title: 'Book',
      authors: [],
      chapters: [
        ReaderChapter(index: 0, title: 'First', blocks: []),
        ReaderChapter(index: 1, title: 'Second', blocks: []),
      ],
    );

    await service.putBook('book', book);
    final metadata = await service.getMetadata('book');
    final bookDir = await service.getBookDir('book');
    final manifestFile = File('${bookDir.path}/manifest.json');
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    manifest['chapters'] = [0, 0];
    await manifestFile.writeAsString(jsonEncode(manifest));

    expect(await service.isCacheValid('book', metadata!), isFalse);
  });

  test('rejects a chapter whose contents no longer match the manifest', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => const CacheSourceFingerprint(
        format: 'txt',
        fileSize: 1,
        fileMtime: 1,
        contentHash: 'hash',
      ),
      storage: _TestStorage(root),
      logger: AppLogger(),
    );
    const book = NormalizedBook(
      id: 'content-hash',
      title: 'Book',
      authors: [],
      chapters: [ReaderChapter(index: 0, title: 'Original', blocks: [])],
    );

    await service.putBook('book', book);
    final bookDir = await service.getBookDir('book');
    await File('${bookDir.path}/ch_0.json').writeAsString(
      jsonEncode(const ReaderChapter(index: 0, title: 'Tampered', blocks: []).toJson()),
    );

    expect(await service.getChapter('book', 0), isNull);
  });

  test('rejects a checksum-valid chapter stored under the wrong index', () async {
    final root = await Directory.systemTemp.createTemp('reader_cache_');
    addTearDown(() => root.delete(recursive: true));
    final service = ReaderCacheService(
      fingerprintProvider: (_) async => const CacheSourceFingerprint(
        format: 'txt',
        fileSize: 1,
        fileMtime: 1,
        contentHash: 'hash',
      ),
      storage: _TestStorage(root),
      logger: AppLogger(),
    );
    const book = NormalizedBook(
      id: 'content-hash',
      title: 'Book',
      authors: [],
      chapters: [ReaderChapter(index: 0, title: 'Original', blocks: [])],
    );

    await service.putBook('book', book);
    final metadata = await service.getMetadata('book');
    final bookDir = await service.getBookDir('book');
    final chapterFile = File('${bookDir.path}/ch_0.json');
    final swappedChapter = jsonEncode(
      const ReaderChapter(index: 1, title: 'Wrong chapter', blocks: []).toJson(),
    );
    await chapterFile.writeAsString(swappedChapter);

    final manifestFile = File('${bookDir.path}/manifest.json');
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final checksums = manifest['chapterChecksums'] as Map<String, dynamic>;
    checksums['0'] = sha256.convert(utf8.encode(swappedChapter)).toString();
    await manifestFile.writeAsString(jsonEncode(manifest));

    expect(await service.isCacheValid('book', metadata!), isTrue);
    expect(await service.getChapter('book', 0), isNull);
  });
}
