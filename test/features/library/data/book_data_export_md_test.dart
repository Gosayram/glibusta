import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/library/data/book_data_export.dart';

TextHighlight _hl({
  String color = '#FFEB3B',
  String text = 'hello',
  String? note,
}) {
  return TextHighlight(
    id: 'hl-1',
    bookId: 'b-1',
    chapterId: 'ch-1',
    chapterIndex: 0,
    blockIndex: 0,
    startOffset: 0,
    endOffset: text.length,
    selectedText: text,
    color: color,
    decoration: 'none',
    noteText: note,
    isOrphaned: false,
    createdAt: DateTime(2025, 1, 15, 10, 30),
  );
}

Bookmark _bm() {
  return Bookmark(
    id: 'bm-1',
    bookId: 'b-1',
    chapterIndex: 2,
    paragraphIndex: 4,
    localOffset: 0.5,
    selectedText: 'some text',
    note: 'my note',
    createdAt: DateTime(2025, 2, 20, 14, 0), // ignore: avoid_redundant_argument_values
  );
}

Note _note() {
  return Note(
    id: 'n-1',
    bookId: 'b-1',
    chapterIndex: 1,
    paragraphIndex: 3,
    localOffset: 0,
    content: 'Important passage',
    highlightColor: '#FF5722',
    createdAt: DateTime(2025, 3, 10, 9, 0), // ignore: avoid_redundant_argument_values
  );
}

void main() {
  group('buildBookExportMarkdown', () {
    test('includes book title as H1', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Мой роман',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(md, contains('# Экспорт данных: Мой роман'));
    });

    test('formats highlights with blockquotes and bold color', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Book',
        highlights: [_hl(color: '#FF0000', text: 'red highlight')],
        bookmarks: [],
        notes: [],
      );
      expect(md, contains('## Выделения'));
      expect(md, contains('**#FF0000**'));
      expect(md, contains('Стр. 1'));
      expect(md, contains('2025-01-15'));
      expect(md, contains('> "red highlight"'));
    });

    test('shows italic highlight note when present', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Book',
        highlights: [_hl(note: 'my note about this')],
        bookmarks: [],
        notes: [],
      );
      expect(md, contains('*Заметка: my note about this*'));
    });

    test('formats bookmarks with blockquotes', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [_bm()],
        notes: [],
      );
      expect(md, contains('## Закладки'));
      expect(md, contains('Стр. 3'));
      expect(md, contains('> some text'));
    });

    test('formats notes with text', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [],
        notes: [_note()],
      );
      expect(md, contains('## Заметки'));
      expect(md, contains('Стр. 2'));
      expect(md, contains('2025-03-10'));
      expect(md, contains('Important passage'));
    });

    test('empty data produces minimal output with title only', () {
      final md = buildBookExportMarkdown(
        bookTitle: 'Empty',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(md, contains('# Экспорт данных: Empty'));
      expect(md, isNot(contains('## Выделения')));
      expect(md, isNot(contains('## Закладки')));
      expect(md, isNot(contains('## Заметки')));
    });
  });

  group('buildBookExportMdFilename', () {
    test('returns correct format', () {
      final name = buildBookExportMdFilename('abc123');
      expect(name, startsWith('glibusta_export_abc123_'));
      expect(name, endsWith('.md'));
    });
  });
}
