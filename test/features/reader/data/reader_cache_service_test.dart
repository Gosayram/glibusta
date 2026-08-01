import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/data/reader_cache_service.dart';

ReaderChapter _chapter(int index, {String title = ''}) {
  return ReaderChapter(
    index: index,
    title: title.isEmpty ? 'Chapter $index' : title,
    blocks: [ReaderBlock(index: 0, text: 'Content of chapter $index')],
  );
}

class _FakeStorage implements AppFileStorage {
  _FakeStorage(this._dir);

  final Directory _dir;

  @override
  Future<Directory> cacheDir() async => _dir;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late ReaderCacheService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_cache_test_');
    service = ReaderCacheService(
      fingerprintProvider: (_) async => null,
      storage: _FakeStorage(tempDir),
      logger: AppLogger(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('getChapter LRU cache', () {
    test('returns chapter from disk on first load', () async {
      final chapter = _chapter(0);
      await service.putChapter('book1', chapter);

      final result = await service.getChapter('book1', 0);
      expect(result, isNotNull);
      expect(result!.index, 0);
      expect(result.title, 'Chapter 0');
    });

    test('returns cached chapter on second load without disk read', () async {
      final chapter = _chapter(0);
      await service.putChapter('book1', chapter);

      await service.getChapter('book1', 0);

      final bookDir = Directory('${tempDir.path}/book1');
      await bookDir.delete(recursive: true);

      final result = await service.getChapter('book1', 0);
      expect(result, isNotNull);
      expect(result!.index, 0);
    });

    test('evicts oldest entries when cache exceeds max size', () async {
      for (var i = 0; i < 11; i++) {
        await service.putChapter('book1', _chapter(i));
      }

      final bookDir = Directory('${tempDir.path}/book1');
      await bookDir.delete(recursive: true);

      final evicted = await service.getChapter('book1', 0);
      expect(evicted, isNull);

      final kept = await service.getChapter('book1', 10);
      expect(kept, isNotNull);
      expect(kept!.index, 10);
    });

    test('cache is scoped per book', () async {
      await service.putChapter('bookA', _chapter(0, title: 'A'));
      await service.putChapter('bookB', _chapter(0, title: 'B'));

      final a = await service.getChapter('bookA', 0);
      final b = await service.getChapter('bookB', 0);

      expect(a!.title, 'A');
      expect(b!.title, 'B');
    });

    test('invalidate clears chapter cache for the book', () async {
      await service.putChapter('book1', _chapter(0));
      await service.getChapter('book1', 0);

      await service.invalidate('book1');

      final result = await service.getChapter('book1', 0);
      expect(result, isNull);
    });
  });
}
