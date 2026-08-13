import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

ReaderChapter _chapter(int index) => ReaderChapter(
  index: index,
  title: 'Chapter $index',
  blocks: const [],
);

Map<int, ReaderChapter> _loadChapters(Iterable<int> indices) => {
  for (final i in indices) i: _chapter(i),
};

void main() {
  group('ReaderState.copyWith loadedChapters reference', () {
    test('preserves reference when loadedChapters is not passed', () {
      final initial = ReaderState(loadedChapters: _loadChapters([0, 1, 2]));
      final updated = initial.copyWith(scrollProgress: 0.5);
      expect(identical(updated.loadedChapters, initial.loadedChapters), isTrue);
    });

    test('creates new reference when loadedChapters is passed', () {
      final initial = ReaderState(loadedChapters: _loadChapters([0, 1, 2]));
      final updated = initial.copyWith(loadedChapters: _loadChapters([0, 1, 2, 3]));
      expect(identical(updated.loadedChapters, initial.loadedChapters), isFalse);
    });

    test('preserves reference across multiple copyWith calls without loadedChapters', () {
      var state = ReaderState(loadedChapters: _loadChapters([0, 1, 2]));
      final originalRef = state.loadedChapters;
      state = state.copyWith(scrollProgress: 0.1);
      state = state.copyWith(uiVisible: false);
      state = state.copyWith(scrollProgress: 0.5);
      expect(identical(state.loadedChapters, originalRef), isTrue);
    });
  });

  group('evictDistantChapters reference preservation', () {
    test('returns same reference when nothing to evict', () {
      final loaded = _loadChapters([0, 1, 2, 3, 4]);
      final result = ReaderContentHelper.evictDistantChapters(2, loaded);
      expect(identical(result, loaded), isTrue);
    });

    test('returns different reference when chapters are evicted', () {
      final loaded = _loadChapters(List.generate(50, (i) => i));
      final result = ReaderContentHelper.evictDistantChapters(25, loaded);
      expect(identical(result, loaded), isFalse);
      expect(result.length, lessThan(loaded.length));
    });

    test('returns same reference for small map within window', () {
      final loaded = _loadChapters([0, 1, 2]);
      final result = ReaderContentHelper.evictDistantChapters(1, loaded);
      expect(identical(result, loaded), isTrue);
    });

    test('returns same reference for continuous mode when nothing to evict', () {
      final loaded = _loadChapters([0, 1, 2, 3, 4]);
      final result = ReaderContentHelper.evictDistantChapters(
        2,
        loaded,
        keepAllBefore: true,
      );
      expect(identical(result, loaded), isTrue);
    });
  });

  group('ReaderState + evictDistantChapters integration', () {
    test('copyWith preserves loadedChapters reference when eviction is no-op', () {
      final chapters = _loadChapters([0, 1, 2, 3, 4]);
      final state = ReaderState(loadedChapters: chapters);

      final windowed = ReaderContentHelper.evictDistantChapters(2, state.loadedChapters);
      final updated = state.copyWith(loadedChapters: windowed);

      expect(identical(updated.loadedChapters, state.loadedChapters), isTrue);
    });

    test('copyWith creates new loadedChapters reference when eviction changes map', () {
      final chapters = _loadChapters(List.generate(50, (i) => i));
      final state = ReaderState(loadedChapters: chapters);

      final windowed = ReaderContentHelper.evictDistantChapters(25, state.loadedChapters);
      final updated = state.copyWith(loadedChapters: windowed);

      expect(identical(updated.loadedChapters, state.loadedChapters), isFalse);
      expect(updated.loadedChapters.length, lessThan(state.loadedChapters.length));
    });
  });
}
