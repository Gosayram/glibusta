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
  group('buildBookExportTxt', () {
    test('includes book title', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Мой роман',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(txt, contains('Экспорт данных: Мой роман'));
    });

    test('formats highlights with color, page, date, quoted text', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Book',
        highlights: [_hl(color: '#FF0000', text: 'red highlight')],
        bookmarks: [],
        notes: [],
      );
      expect(txt, contains('ВЫДЕЛЕНИЯ'));
      expect(txt, contains('#FF0000'));
      expect(txt, contains('Стр. 1'));
      expect(txt, contains('2025-01-15'));
      expect(txt, contains('"red highlight"'));
    });

    test('shows highlight note when present', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Book',
        highlights: [_hl(note: 'my note about this')],
        bookmarks: [],
        notes: [],
      );
      expect(txt, contains('Заметка: my note about this'));
    });

    test('formats bookmarks with page and surrounding text', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [_bm()],
        notes: [],
      );
      expect(txt, contains('ЗАКЛАДКИ'));
      expect(txt, contains('Стр. 3'));
      expect(txt, contains('Текст: some text'));
    });

    test('formats notes with page and date', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [],
        notes: [_note()],
      );
      expect(txt, contains('ЗАМЕТКИ'));
      expect(txt, contains('Стр. 2'));
      expect(txt, contains('2025-03-10'));
      expect(txt, contains('Important passage'));
    });

    test('empty data produces minimal output with title only', () {
      final txt = buildBookExportTxt(
        bookTitle: 'Empty',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(txt, contains('Экспорт данных: Empty'));
      expect(txt, isNot(contains('ВЫДЕЛЕНИЯ')));
      expect(txt, isNot(contains('ЗАКЛАДКИ')));
      expect(txt, isNot(contains('ЗАМЕТКИ')));
    });
  });

  group('buildBookExportTxtFilename', () {
    test('returns correct format', () {
      final name = buildBookExportTxtFilename('abc123');
      expect(name, startsWith('glibusta_export_abc123_'));
      expect(name, endsWith('.txt'));
    });
  });
}
