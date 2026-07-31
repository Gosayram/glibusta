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

Note _note({String color = '#FF5722'}) {
  return Note(
    id: 'n-1',
    bookId: 'b-1',
    chapterIndex: 1,
    paragraphIndex: 3,
    localOffset: 0,
    content: 'Important passage',
    highlightColor: color,
    createdAt: DateTime(2025, 3, 10, 9, 0), // ignore: avoid_redundant_argument_values
  );
}

void main() {
  group('buildBookExportHtml', () {
    test('contains valid HTML structure', () {
      final html = buildBookExportHtml(
        bookTitle: 'Test Book',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<html lang="ru">'));
      expect(html, contains('<head>'));
      expect(html, contains('<body>'));
      expect(html, endsWith('</body></html>'));
    });

    test('title appears in <title> and <h1>', () {
      final html = buildBookExportHtml(
        bookTitle: 'Мой роман',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(html, contains('<title>Мой роман</title>'));
      expect(html, contains('<h1>Мой роман</h1>'));
    });

    test('highlights render with correct colors', () {
      final html = buildBookExportHtml(
        bookTitle: 'Book',
        highlights: [_hl(color: '#FF0000', text: 'red highlight')],
        bookmarks: [],
        notes: [],
      );
      expect(html, contains('Выделения'));
      expect(html, contains('background-color:#FF0000'));
      expect(html, contains('red highlight'));
    });

    test('highlight with note shows note text', () {
      final html = buildBookExportHtml(
        bookTitle: 'Book',
        highlights: [_hl(note: 'my note about this')],
        bookmarks: [],
        notes: [],
      );
      expect(html, contains('my note about this'));
    });

    test('bookmarks show chapter and paragraph info', () {
      final html = buildBookExportHtml(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [_bm()],
        notes: [],
      );
      expect(html, contains('Закладки'));
      expect(html, contains('Глава 3'));
      expect(html, contains('абзац 5'));
      expect(html, contains('some text'));
      expect(html, contains('my note'));
    });

    test('notes show content and anchor', () {
      final html = buildBookExportHtml(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [],
        notes: [_note()],
      );
      expect(html, contains('Заметки'));
      expect(html, contains('Important passage'));
      expect(html, contains('Глава 2'));
      expect(html, contains('абзац 4'));
    });

    test('empty lists produce valid HTML with no section headings', () {
      final html = buildBookExportHtml(
        bookTitle: 'Empty',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      expect(html, isNot(contains('Выделения')));
      expect(html, isNot(contains('Закладки')));
      expect(html, isNot(contains('Заметки')));
      expect(html, contains('<title>Empty</title>'));
    });

    test('HTML-escapes special characters in content', () {
      final html = buildBookExportHtml(
        bookTitle: '<script>alert("xss")</script>',
        highlights: [_hl(text: '<b>bold</b> & "quotes"')],
        bookmarks: [],
        notes: [],
      );
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&lt;b&gt;bold&lt;/b&gt;'));
      expect(html, contains('&amp;'));
      expect(html, contains('&quot;'));
    });
  });

  group('buildBookExportHtmlFilename', () {
    test('returns correct format', () {
      final name = buildBookExportHtmlFilename('abc123');
      expect(name, startsWith('glibusta_export_abc123_'));
      expect(name, endsWith('.html'));
    });
  });
}
