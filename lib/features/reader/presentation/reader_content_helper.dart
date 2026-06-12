import '../../../core/logging/app_logger.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';

const int chapterWindowSize = 2;

class ReaderContentHelper {
  ReaderContentHelper(this._service, this._bookId);

  final BookOpenService _service;
  final String _bookId;
  final _logger = AppLogger();

  Future<NormalizedBookMetadata> loadMetadata() async {
    final cached = await _service.getCachedMetadata(_bookId);
    if (cached != null) {
      _logger.fine('Metadata cache hit for $_bookId', name: 'Reader');
      return cached;
    }
    _logger.info('Loading fresh metadata for $_bookId', name: 'Reader');
    final book = await _service.openBookWithCache(_bookId);
    return book.toMetadata();
  }

  Future<Map<int, ReaderChapter>> ensureChaptersLoaded(
    int centerIndex,
    Map<int, ReaderChapter> currentlyLoaded, {
    int windowSize = chapterWindowSize,
  }) async {
    final minIdx = (centerIndex - windowSize).clamp(0, centerIndex + windowSize);
    final maxIdx = (centerIndex + windowSize);

    final toLoad = <int>[];
    for (var i = minIdx; i <= maxIdx; i++) {
      if (!currentlyLoaded.containsKey(i)) {
        toLoad.add(i);
      }
    }

    if (toLoad.isEmpty) return currentlyLoaded;

    _logger.fine('Loading chapters: $toLoad', name: 'Reader');
    final updates = Map<int, ReaderChapter>.from(currentlyLoaded);
    for (final idx in toLoad) {
      final chapter = await _service.loadChapter(_bookId, idx);
      if (chapter != null) {
        updates[idx] = chapter;
      } else {
        _logger.warning('Chapter $idx returned null', name: 'Reader');
      }
    }
    return updates;
  }

  Map<int, ReaderChapter> evictDistantChapters(
    int centerIndex,
    Map<int, ReaderChapter> loaded, {
    int windowSize = chapterWindowSize + 1,
  }) {
    final minKeep = (centerIndex - windowSize).clamp(0, centerIndex + windowSize);
    final maxKeep = centerIndex + windowSize;

    final updated = Map<int, ReaderChapter>.from(loaded);
    final keysToRemove = <int>[];
    for (final key in updated.keys) {
      if (key < minKeep || key > maxKeep) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        updated.remove(key);
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
