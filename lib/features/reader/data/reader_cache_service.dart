import 'dart:convert';
import 'dart:io';

import '../../../core/database/full_text_search.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import 'parsers/normalized_book.dart';

final class CacheSourceFingerprint {
  const CacheSourceFingerprint({
    required this.format,
    required this.fileSize,
    required this.fileMtime,
    required this.contentHash,
  });

  final String format;
  final int fileSize;
  final int fileMtime;
  final String? contentHash;
}

typedef CacheFingerprintProvider = Future<CacheSourceFingerprint?> Function(String bookId);

final class ReaderCacheService {
  ReaderCacheService({
    required CacheFingerprintProvider fingerprintProvider,
    required AppFileStorage storage,
    required AppLogger logger,
    FullTextSearchService? ftsService,
  }) : _fingerprintProvider = fingerprintProvider,
       _storage = storage,
       _logger = logger,
       _ftsService = ftsService;

  final CacheFingerprintProvider _fingerprintProvider;
  final AppFileStorage _storage;
  final FullTextSearchService? _ftsService;
  final AppLogger _logger;

  static const int _splitCacheVersion = 1;
  static const int _parserCacheVersion = 1;

  Future<String> get booksCacheDir async {
    final dir = await _storage.cacheDir();
    return dir.path;
  }

  Future<File> _getLegacyCacheFile(String bookId) async {
    final dir = await booksCacheDir;
    return File('$dir/$bookId.json');
  }

  Future<Directory> getBookDir(String bookId) async {
    final dir = await booksCacheDir;
    final bookDir = Directory('$dir/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return bookDir;
  }

  Future<Directory> _getExistingBookDir(String bookId) async {
    final dir = await booksCacheDir;
    return Directory('$dir/$bookId');
  }

  File _getMetadataFile(Directory bookDir) => File('${bookDir.path}/meta.json');

  File _getManifestFile(Directory bookDir) => File('${bookDir.path}/manifest.json');

  File _getChapterFile(Directory bookDir, int index) => File('${bookDir.path}/ch_$index.json');

  Future<void> _writeJsonAtomically(File target, Object? value) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  Future<NormalizedBookMetadata?> getMetadata(String bookId) async {
    try {
      final bookDir = await _getExistingBookDir(bookId);
      if (!await bookDir.exists()) return null;
      final metaFile = _getMetadataFile(bookDir);
      if (!await metaFile.exists()) return null;
      final json = await metaFile.readAsString();
      return NormalizedBookMetadata.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } on Object catch (e) {
      _logger.warning(
        'Failed to read cached metadata: $e',
        name: 'ReaderCache',
        error: e,
      );
      return null;
    }
  }

  Future<bool> isCacheValid(
    String bookId,
    NormalizedBookMetadata meta,
  ) async {
    final bookDir = await _getExistingBookDir(bookId);
    if (!await bookDir.exists()) return false;
    return _isSplitCacheValid(bookDir, meta);
  }

  Future<ReaderChapter?> getChapter(String bookId, int index) async {
    try {
      final bookDir = await _getExistingBookDir(bookId);
      if (!await bookDir.exists()) return null;
      final chapterFile = _getChapterFile(bookDir, index);
      if (!await chapterFile.exists()) return null;
      final json = await chapterFile.readAsString();
      return ReaderChapter.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning(
        'Failed to load chapter $index for $bookId: $e',
        name: 'ReaderCache',
        error: e,
      );
      return null;
    }
  }

  Future<void> putChapter(String bookId, ReaderChapter chapter) async {
    final bookDir = await getBookDir(bookId);
    final chapterFile = _getChapterFile(bookDir, chapter.index);
    await _writeJsonAtomically(chapterFile, chapter.toJson());
  }

  Future<void> putBook(String bookId, NormalizedBook book) async {
    await _saveSplitCache(bookId, book);
  }

  Future<void> invalidate(
    String bookId, {
    bool preserveImages = false,
  }) async {
    final bookDir = await _getExistingBookDir(bookId);
    if (!await bookDir.exists()) return;
    try {
      if (preserveImages) {
        final imagesDir = Directory('${bookDir.path}/epub_images');
        final hasImages = await imagesDir.exists();
        final backupPath =
            '${bookDir.path}.epub_images_bak_${DateTime.now().microsecondsSinceEpoch}';
        final imagesBackup = hasImages ? await imagesDir.rename(backupPath) : null;

        try {
          await bookDir.delete(recursive: true);
        } on Object {
          if (imagesBackup != null) {
            await imagesBackup.rename('${bookDir.path}/epub_images');
          }
          rethrow;
        }

        if (imagesBackup != null) {
          await bookDir.create(recursive: true);
          await imagesBackup.rename('${bookDir.path}/epub_images');
        }
      } else {
        await bookDir.delete(recursive: true);
      }
      _logger.info(
        'Reader cache invalidated for $bookId (preserveImages=$preserveImages)',
        name: 'ReaderCache',
      );
    } on Object catch (e) {
      _logger.warning(
        'Failed to invalidate reader cache for $bookId: $e',
        name: 'ReaderCache',
        error: e,
      );
    }
  }

  Future<NormalizedBook?> getCachedBook(String bookId) async {
    final cacheFile = await _getLegacyCacheFile(bookId);
    if (!await cacheFile.exists()) return null;
    try {
      final json = await cacheFile.readAsString();
      return NormalizedBook.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on Object catch (e) {
      _logger.warning(
        'Failed to read cached book: $e',
        name: 'ReaderCache',
        error: e,
      );
      return null;
    }
  }

  Future<void> saveToCache(String bookId, NormalizedBook book) async {
    final cacheFile = await _getLegacyCacheFile(bookId);
    await cacheFile.writeAsString(jsonEncode(book.toJson()));
  }

  Future<void> migrateLegacyCache(String bookId, NormalizedBook book) async {
    try {
      await _saveSplitCache(bookId, book);
    } on Object catch (e, st) {
      _logger.warning(
        'Legacy cache migration failed for $bookId: $e',
        name: 'ReaderCache',
        error: e,
        st: st,
      );
    }
  }

  Future<({int fileCount, int sizeBytes})> getStats() async {
    final baseDir = await booksCacheDir;
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      return (fileCount: 0, sizeBytes: 0);
    }
    var fileCount = 0;
    var sizeBytes = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          sizeBytes += await entity.length();
        }
      }
    } on Object catch (e) {
      _logger.warning(
        'Failed to compute cache stats: $e',
        name: 'ReaderCache',
        error: e,
      );
    }
    return (fileCount: fileCount, sizeBytes: sizeBytes);
  }

  Future<bool> _isSplitCacheValid(
    Directory bookDir,
    NormalizedBookMetadata meta,
  ) async {
    final manifestFile = _getManifestFile(bookDir);
    if (await manifestFile.exists()) {
      try {
        final json = await manifestFile.readAsString();
        final manifest = jsonDecode(json) as Map<String, dynamic>;
        final version = manifest['version'] as int?;
        final parserVersion = manifest['parserVersion'] as int?;
        final cachedFormat = manifest['format'] as String?;
        final cachedFileSize = manifest['fileSize'] as int?;
        final cachedFileMtime = manifest['fileMtime'] as int?;
        final cachedContentHash = manifest['contentHash'] as String?;
        final chapterCount = manifest['chapterCount'] as int?;
        final chapters = (manifest['chapters'] as List<dynamic>?)?.cast<int>() ?? const <int>[];
        final source = await _fingerprintProvider(meta.id);
        if (source == null) {
          return false;
        }
        if (version != _splitCacheVersion ||
            parserVersion != _parserCacheVersion ||
            cachedFormat != source.format ||
            cachedFileSize != source.fileSize ||
            cachedFileMtime != source.fileMtime ||
            cachedContentHash != source.contentHash ||
            chapterCount != meta.chapterCount ||
            chapters.length != meta.chapterCount) {
          return false;
        }
        for (final index in chapters) {
          if (!await _getChapterFile(bookDir, index).exists()) return false;
        }
        return true;
      } on Object catch (e) {
        _logger.warning(
          'Failed to validate split cache manifest: $e',
          name: 'ReaderCache',
          error: e,
        );
        return false;
      }
    }

    return false;
  }

  Future<void> _saveSplitCache(String bookId, NormalizedBook book) async {
    final bookDir = await getBookDir(bookId);
    final metaFile = _getMetadataFile(bookDir);
    final source = await _fingerprintProvider(bookId);
    await _writeJsonAtomically(metaFile, book.toMetadata().toJson());
    for (final chapter in book.chapters) {
      final chapterFile = _getChapterFile(bookDir, chapter.index);
      await _writeJsonAtomically(chapterFile, chapter.toJson());
    }
    await _writeJsonAtomically(
      _getManifestFile(bookDir),
      {
        'version': _splitCacheVersion,
        'parserVersion': _parserCacheVersion,
        'bookId': bookId,
        'format': source?.format,
        'fileSize': source?.fileSize,
        'fileMtime': source?.fileMtime,
        'contentHash': source?.contentHash,
        'chapterCount': book.chapters.length,
        'chapters': book.chapters.map((chapter) => chapter.index).toList(),
      },
    );

    // Index content for full-text search
    await _indexFtsContent(bookId, book);
  }

  Future<void> _indexFtsContent(String bookId, NormalizedBook book) async {
    if (_ftsService == null) return;
    try {
      final chapters = <BookChapterContent>[];
      for (final chapter in book.chapters) {
        final textParts = <String>[];
        for (final block in chapter.blocks) {
          if (block.text.isNotEmpty) {
            textParts.add(block.text);
          }
        }
        if (textParts.isNotEmpty) {
          chapters.add(
            BookChapterContent(
              chapterIndex: chapter.index,
              title: chapter.title,
              content: textParts.join('\n'),
            ),
          );
        }
      }
      if (chapters.isNotEmpty) {
        await _ftsService.indexBook(bookId: bookId, chapters: chapters);
      }
    } on Object catch (e) {
      _logger.warning('FTS indexing failed for $bookId: $e', name: 'Cache', error: e);
    }
  }
}
