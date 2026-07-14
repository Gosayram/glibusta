import 'dart:io';

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
}
