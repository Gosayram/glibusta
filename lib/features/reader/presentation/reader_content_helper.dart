import '../../../core/logging/app_logger.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';

const int chapterWindowSize = 2;
// MD-2.3: max loaded chapters before eviction kicks in
const int maxLoadedChapters = 20;

final class ReaderContentHelper {
  ReaderContentHelper(this._service, this._bookId, this._logger);

  final BookOpenService _service;
  final String _bookId;
  final AppLogger _logger;

  Future<NormalizedBookMetadata> loadMetadata({void Function(String)? onCacheMode}) async {
    final cached = await _service.getCachedMetadata(_bookId);
    if (cached != null) {
      _logger.fine('Metadata cache hit for $_bookId', name: 'Reader');
      onCacheMode?.call('split');
      return cached;
    }
    _logger.info('Loading fresh metadata for $_bookId', name: 'Reader');
    onCacheMode?.call('fresh');
    final book = await _service.openBookWithCache(_bookId, loadChapters: false);
    return book.toMetadata();
  }

  /// MD-2.3: adaptive window — larger books get a bigger preload window
  int _adaptiveWindow(int chapterCount) {
    if (chapterCount > 500) return 4;
    if (chapterCount > 200) return 3;
    return chapterWindowSize;
  }

  Future<Map<int, ReaderChapter>> ensureChaptersLoaded(
    int centerIndex,
    Map<int, ReaderChapter> currentlyLoaded, {
    required int chapterCount,
    int? windowSize,
  }) async {
    if (chapterCount <= 0) return currentlyLoaded;

    final lastIndex = chapterCount - 1;
    final safeCenter = centerIndex.clamp(0, lastIndex);
    final win = windowSize ?? _adaptiveWindow(chapterCount);
    final minIdx = (safeCenter - win).clamp(0, lastIndex);
    final maxIdx = (safeCenter + win).clamp(0, lastIndex);

    final toLoad = <int>[];
    for (var i = minIdx; i <= maxIdx; i++) {
      if (!currentlyLoaded.containsKey(i)) {
        toLoad.add(i);
      }
    }

    if (toLoad.isEmpty) return currentlyLoaded;

    _logger.fine('Loading chapters: $toLoad', name: 'Reader');
    final updates = Map<int, ReaderChapter>.from(currentlyLoaded);
    // MD-2.3: parallel batch loading instead of sequential
    final results = await Future.wait(
      toLoad.map((idx) => _service.loadChapter(_bookId, idx)),
    );
    for (var i = 0; i < toLoad.length; i++) {
      final chapter = results[i];
      if (chapter != null) {
        updates[toLoad[i]] = chapter;
      } else {
        _logger.warning('Chapter ${toLoad[i]} returned null', name: 'Reader');
      }
    }
    return updates;
  }

  Map<int, ReaderChapter> evictDistantChapters(
    int centerIndex,
    Map<int, ReaderChapter> loaded, {
    int? windowSize,
  }) {
    final win = (windowSize ?? chapterWindowSize + 1);
    final minKeep = (centerIndex - win).clamp(0, centerIndex + win);
    final maxKeep = centerIndex + win;

    final updated = Map<int, ReaderChapter>.from(loaded);
    final keysToRemove = <int>[];
    for (final key in updated.keys) {
      if (key < minKeep || key > maxKeep) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      updated.remove(key);
    }

    // MD-2.3: memory pressure — if too many chapters loaded, evict farthest
    if (updated.length > maxLoadedChapters) {
      final sortedKeys = updated.keys.toList()
        ..sort((a, b) => (a - centerIndex).abs().compareTo((b - centerIndex).abs()));
      while (updated.length > maxLoadedChapters) {
        final farthest = sortedKeys.removeLast();
        updated.remove(farthest);
      }
    }

    return updated;
  }

  int computeTotalWords(Map<int, ReaderChapter> chapters) {
    var total = 0;
    for (final chapter in chapters.values) {
      for (final block in chapter.blocks) {
        total += block.text.split(RegExp(r'\s+')).length;
      }
    }
    return total;
  }

  NormalizedBook buildBookForSearch(
    NormalizedBookMetadata meta,
    Map<int, ReaderChapter> loadedChapters,
  ) {
    final chapters = <ReaderChapter>[];
    for (var i = 0; i < meta.chapterCount; i++) {
      chapters.add(
        loadedChapters[i] ??
            ReaderChapter(index: i, title: meta.chapterTitles[i], blocks: const []),
      );
    }
    return NormalizedBook(
      id: meta.id,
      title: meta.title,
      authors: meta.authors,
      description: meta.description,
      coverUrl: meta.coverUrl,
      chapters: chapters,
      metadata: meta.metadata,
    );
  }
}
