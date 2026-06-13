import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/events/app_events.dart';

void main() {
  group('AppEvent subclasses', () {
    test('BookDownloadedEvent has correct fields and toJson', () {
      const e = BookDownloadedEvent(
        bookId: 'b1',
        filePath: '/path/file.epub',
        sizeBytes: 1024,
      );
      expect(e.bookId, 'b1');
      expect(e.filePath, '/path/file.epub');
      expect(e.sizeBytes, 1024);
      expect(e.name, 'BookDownloadedEvent');
      final json = e.toJson();
      expect(json['bookId'], 'b1');
      expect(json['filePath'], '/path/file.epub');
      expect(json['sizeBytes'], 1024);
      expect(json['type'], 'BookDownloadedEvent');
      expect(json.containsKey('ts'), isTrue);
    });

    test('BookImportedEvent toJson', () {
      const e = BookImportedEvent(bookId: 'b2', format: 'epub');
      expect(e.bookId, 'b2');
      expect(e.format, 'epub');
      final json = e.toJson();
      expect(json['format'], 'epub');
    });

    test('BookDeletedEvent has correct fields', () {
      const e = BookDeletedEvent(bookId: 'b3', filePath: '/f.fb2');
      expect(e.bookId, 'b3');
      expect(e.filePath, '/f.fb2');
    });

    test('BookOpenedEvent has correct fields', () {
      const e = BookOpenedEvent(bookId: 'b4', format: 'txt');
      expect(e.bookId, 'b4');
      expect(e.format, 'txt');
    });

    test('ProgressChangedEvent fields', () {
      const e = ProgressChangedEvent(
        bookId: 'b5',
        chapterIndex: 3,
        totalChapters: 10,
        progressPercent: 0.3,
      );
      expect(e.bookId, 'b5');
      expect(e.chapterIndex, 3);
      expect(e.totalChapters, 10);
      expect(e.progressPercent, 0.3);
      expect(e.name, 'ProgressChangedEvent');
    });

    test('BookmarkCreatedEvent fields', () {
      const e = BookmarkCreatedEvent(
        bookId: 'b6',
        chapterIndex: 1,
        label: 'ch1',
      );
      expect(e.label, 'ch1');
    });

    test('BookmarkDeletedEvent fields', () {
      const e = BookmarkDeletedEvent(bookId: 'b7', bookmarkId: 'bm1');
      expect(e.bookmarkId, 'bm1');
    });

    test('NoteCreatedEvent fields', () {
      const e = NoteCreatedEvent(bookId: 'b8', chapterIndex: 2);
      expect(e.chapterIndex, 2);
    });

    test('NoteDeletedEvent fields', () {
      const e = NoteDeletedEvent(bookId: 'b9', noteId: 'n1');
      expect(e.noteId, 'n1');
    });

    test('QuoteSavedEvent fields', () {
      const e = QuoteSavedEvent(bookId: 'b10', text: 'hello');
      expect(e.text, 'hello');
    });

    test('SearchPerformedEvent fields', () {
      const e = SearchPerformedEvent(
        query: 'pushkin',
        resultCount: 5,
        isOffline: true,
      );
      expect(e.query, 'pushkin');
      expect(e.resultCount, 5);
      expect(e.isOffline, isTrue);
      expect(e.name, 'SearchPerformedEvent');
    });

    test('CacheClearedEvent fields', () {
      const e = CacheClearedEvent(bytesFreed: 1024000);
      expect(e.bytesFreed, 1024000);
    });

    test('ErrorOccurredEvent fields', () {
      const e = ErrorOccurredEvent(
        source: 'parser',
        message: 'bad xml',
        stackTrace: 'at line 5',
      );
      expect(e.source, 'parser');
      expect(e.stackTrace, 'at line 5');
    });

    test('SettingsChangedEvent fields', () {
      const e = SettingsChangedEvent(key: 'theme', value: 'dark');
      expect(e.key, 'theme');
      expect(e.value, 'dark');
    });

    test('DownloadFailedEvent fields', () {
      const e = DownloadFailedEvent(bookId: 'b11', reason: '404');
      expect(e.reason, '404');
    });

    test('IndexingCompletedEvent fields', () {
      const e = IndexingCompletedEvent(
        booksIndexed: 100,
        duplicatesFound: 5,
        durationMs: 2500,
      );
      expect(e.booksIndexed, 100);
      expect(e.durationMs, 2500);
    });
  });

  group('RingBuffer', () {
    test('starts empty', () {
      final buf = RingBuffer<int>(5);
      expect(buf.length, 0);
      expect(buf.isFull, isFalse);
      expect(buf.toList(), isEmpty);
      expect(buf.last, isNull);
    });

    test('add increases length', () {
      final buf = RingBuffer<int>(3);
      buf.add(1);
      expect(buf.length, 1);
      buf.add(2);
      expect(buf.length, 2);
    });

    test('isFull when at capacity', () {
      final buf = RingBuffer<int>(2);
      buf.add(1);
      buf.add(2);
      expect(buf.isFull, isTrue);
    });

    test('add evicts oldest when full', () {
      final buf = RingBuffer<int>(3);
      buf.add(1);
      buf.add(2);
      buf.add(3);
      buf.add(4);
      expect(buf.toList(), [2, 3, 4]);
      expect(buf.length, 3);
    });

    test('last returns most recent', () {
      final buf = RingBuffer<int>(3);
      buf.add(10);
      buf.add(20);
      expect(buf.last, 20);
    });

    test('clear empties buffer', () {
      final buf = RingBuffer<int>(3);
      buf.add(1);
      buf.add(2);
      buf.clear();
      expect(buf.length, 0);
      expect(buf.last, isNull);
    });
  });

  group('EventBus', () {
    test('fire adds to history', () {
      final bus = EventBus(historySize: 10);
      const e = BookDownloadedEvent(
        bookId: 'b1',
        filePath: '/f',
        sizeBytes: 100,
      );
      bus.fire(e);
      expect(bus.history.length, 1);
      expect(bus.lastEvent, isA<BookDownloadedEvent>());
      bus.dispose();
    });

    test('stream emits fired events', () async {
      final bus = EventBus();
      final events = <AppEvent>[];
      bus.stream.listen(events.add);
      const e = BookImportedEvent(bookId: 'b1', format: 'epub');
      bus.fire(e);
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);
      expect(events.first, isA<BookImportedEvent>());
      bus.dispose();
    });

    test('on<T> filters by type', () async {
      final bus = EventBus();
      final downloads = <BookDownloadedEvent>[];
      bus.on<BookDownloadedEvent>().listen(downloads.add);
      bus.fire(const BookImportedEvent(bookId: 'b1', format: 'epub'));
      bus.fire(
        const BookDownloadedEvent(
          bookId: 'b2',
          filePath: '/f',
          sizeBytes: 100,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(downloads.length, 1);
      expect(downloads.first.bookId, 'b2');
      bus.dispose();
    });

    test('history respects capacity', () {
      final bus = EventBus(historySize: 2);
      for (var i = 0; i < 5; i++) {
        bus.fire(const BookImportedEvent(bookId: 'b', format: 'fb2'));
      }
      expect(bus.history.length, 2);
      bus.dispose();
    });

    test('fire after dispose is safe (does not throw)', () {
      final bus = EventBus();
      bus.dispose();
      expect(
        () => bus.fire(const CacheClearedEvent(bytesFreed: 0)),
        returnsNormally,
      );
    });

    test('fire after dispose does not add to history', () {
      final bus = EventBus();
      bus.fire(const BookImportedEvent(bookId: 'a', format: 'epub'));
      bus.dispose();
      bus.fire(const BookImportedEvent(bookId: 'b', format: 'epub'));
      expect(bus.history.length, 1);
    });

    test('history returns events in order', () {
      final bus = EventBus(historySize: 5);
      bus.fire(const BookImportedEvent(bookId: '1', format: 'epub'));
      bus.fire(const BookImportedEvent(bookId: '2', format: 'fb2'));
      bus.fire(const BookImportedEvent(bookId: '3', format: 'txt'));
      final history = bus.history;
      expect(history.length, 3);
      expect((history[0] as BookImportedEvent).bookId, '1');
      expect((history[2] as BookImportedEvent).bookId, '3');
      bus.dispose();
    });
  });
}
