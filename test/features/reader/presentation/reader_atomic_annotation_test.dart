import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/highlights/data/highlight_repository.dart';

void main() {
  late AppDatabase db;
  late HighlightRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HighlightRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HighlightRepository.saveHighlight — atomic creation', () {
    test('valid highlight is saved completely', () async {
      final id = await repo.saveHighlight(
        bookId: 'book-1',
        chapterId: 'ch-0',
        chapterIndex: 0,
        blockIndex: 0,
        startOffset: 0,
        endOffset: 4,
        selectedText: 'Test',
        color: 'yellow',
      );

      expect(id, greaterThan(0));

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, hasLength(1));
      expect(highlights.first.selectedText, 'Test');
      expect(highlights.first.bookId, 'book-1');
      expect(highlights.first.chapterId, 'ch-0');
      expect(highlights.first.chapterIndex, 0);
      expect(highlights.first.blockIndex, 0);
      expect(highlights.first.startOffset, 0);
      expect(highlights.first.endOffset, 4);
      expect(highlights.first.color, 'yellow');
    });

    test('highlight with note and decoration is saved', () async {
      await repo.saveHighlight(
        bookId: 'book-1',
        chapterId: 'ch-0',
        chapterIndex: 0,
        blockIndex: 0,
        startOffset: 0,
        endOffset: 4,
        selectedText: 'Test',
        color: 'blue',
        noteText: 'My note',
        decoration: 'underline',
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, hasLength(1));
      expect(highlights.first.noteText, 'My note');
      expect(highlights.first.decoration, 'underline');
    });
  });

  group('HighlightRepository.saveHighlight — validation rejects invalid data', () {
    test('empty bookId is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: '',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 4,
          selectedText: 'Test',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('');
      expect(highlights, isEmpty);
    });

    test('empty selectedText is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 0,
          selectedText: '',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });

    test('whitespace-only selectedText is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 3,
          selectedText: '   ',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });

    test('negative chapterIndex is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: -1,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 4,
          selectedText: 'Test',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });

    test('negative blockIndex is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: -1,
          startOffset: 0,
          endOffset: 4,
          selectedText: 'Test',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });

    test('negative startOffset is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: -1,
          endOffset: 4,
          selectedText: 'Test',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });

    test('endOffset < startOffset is rejected', () async {
      await expectLater(
        () => repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 10,
          endOffset: 5,
          selectedText: 'Test',
          color: 'yellow',
        ),
        throwsA(isA<HighlightValidationException>()),
      );

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, isEmpty);
    });
  });

  group('HighlightRepository.validateHighlight — unit validation', () {
    test('valid data passes without throwing', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'Hello',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 5,
        ),
        returnsNormally,
      );
    });

    test('empty bookId throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: '',
          selectedText: 'Hello',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 5,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('empty selectedText throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: '',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 0,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('negative chapterIndex throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'Hello',
          chapterIndex: -1,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 5,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('negative blockIndex throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'Hello',
          chapterIndex: 0,
          blockIndex: -1,
          startOffset: 0,
          endOffset: 5,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('negative startOffset throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'Hello',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: -1,
          endOffset: 5,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('endOffset < startOffset throws', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'Hello',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 10,
          endOffset: 3,
        ),
        throwsA(isA<HighlightValidationException>()),
      );
    });

    test('endOffset == startOffset is valid (zero-length selection)', () {
      expect(
        () => HighlightRepository.validateHighlight(
          bookId: 'book-1',
          selectedText: 'X',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 5,
          endOffset: 5,
        ),
        returnsNormally,
      );
    });
  });

  group('Transaction rollback on error', () {
    test('no partial data remains when validation fails after partial work', () async {
      await repo.saveHighlight(
        bookId: 'book-1',
        chapterId: 'ch-0',
        chapterIndex: 0,
        blockIndex: 0,
        startOffset: 0,
        endOffset: 4,
        selectedText: 'First',
        color: 'yellow',
      );

      try {
        await repo.saveHighlight(
          bookId: '',
          chapterId: 'ch-0',
          chapterIndex: 0,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 6,
          selectedText: 'Second',
          color: 'blue',
        );
      } on Object catch (_) {}

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, hasLength(1));
      expect(highlights.first.selectedText, 'First');
    });

    test('multiple valid highlights are all persisted', () async {
      for (var i = 0; i < 5; i++) {
        await repo.saveHighlight(
          bookId: 'book-1',
          chapterId: 'ch-$i',
          chapterIndex: i,
          blockIndex: 0,
          startOffset: 0,
          endOffset: 4,
          selectedText: 'Text $i',
          color: 'yellow',
        );
      }

      final highlights = await repo.getHighlightsForBook('book-1');
      expect(highlights, hasLength(5));
    });
  });
}
