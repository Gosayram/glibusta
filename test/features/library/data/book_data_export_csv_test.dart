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
  group('buildBookExportCsv', () {
    test('has correct headers', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      final firstLine = csv.split('\n').first;
      expect(firstLine, 'Type;Text;Note;Color;Page;Chapter;Date');
    });

    test('formats highlights as rows with correct columns', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [_hl(text: 'red highlight', color: '#FF0000')],
        bookmarks: [],
        notes: [],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 2);
      expect(
        lines[1],
        startsWith('Highlight;red highlight;;#FF0000;1;ch-1;'),
      );
      expect(lines[1], contains('2025-01-15'));
    });

    test('escapes fields containing semicolons', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [_hl(text: 'hello; world')],
        bookmarks: [],
        notes: [],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines[1], contains('"hello; world"'));
    });

    test('escapes fields containing quotes', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [_hl(text: 'say "hi"')],
        bookmarks: [],
        notes: [],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines[1], contains('"say ""hi"""'));
    });

    test('formats bookmarks as rows', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [_bm()],
        notes: [],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 2);
      expect(lines[1], startsWith('Bookmark;some text;my note;;3;;'));
      expect(lines[1], contains('2025-02-20'));
    });

    test('formats notes as rows', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Book',
        highlights: [],
        bookmarks: [],
        notes: [_note()],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 2);
      expect(lines[1], startsWith('Note;Important passage;;#FF5722;2;;'));
      expect(lines[1], contains('2025-03-10'));
    });

    test('empty data returns just headers', () {
      final csv = buildBookExportCsv(
        bookTitle: 'Empty',
        highlights: [],
        bookmarks: [],
        notes: [],
      );
      final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 1);
      expect(lines[0], 'Type;Text;Note;Color;Page;Chapter;Date');
    });
  });

  group('buildBookExportCsvFilename', () {
    test('returns correct format', () {
      final name = buildBookExportCsvFilename('abc123');
      expect(name, startsWith('glibusta_export_abc123_'));
      expect(name, endsWith('.csv'));
    });
  });
}
