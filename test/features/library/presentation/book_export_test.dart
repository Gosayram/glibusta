import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/library/data/book_data_export.dart';

void main() {
  final highlights = [
    TextHighlight(
      id: 'hl1',
      bookId: 'book1',
      chapterId: 'ch1',
      chapterIndex: 0,
      blockIndex: 2,
      startOffset: 10,
      endOffset: 30,
      selectedText: 'Выделенный текст',
      color: 'yellow',
      decoration: 'none',
      noteText: 'Заметка к выделению',
      isOrphaned: false,
      createdAt: DateTime.utc(2026, 7, 29, 12),
      updatedAt: DateTime.utc(2026, 7, 30),
    ),
    TextHighlight(
      id: 'hl2',
      bookId: 'book1',
      chapterId: 'ch2',
      chapterIndex: 1,
      blockIndex: 0,
      startOffset: 5,
      endOffset: 20,
      selectedText: 'Второе выделение',
      color: 'green',
      decoration: 'none',
      isOrphaned: false,
      createdAt: DateTime.utc(2026, 7, 29, 13),
    ),
  ];

  final bookmarks = [
    Bookmark(
      id: 'bm1',
      bookId: 'book1',
      chapterIndex: 2,
      paragraphIndex: 5,
      localOffset: 0.75,
      selectedText: 'Текст закладки',
      note: 'Пометка',
      createdAt: DateTime.utc(2026, 7, 29, 14),
    ),
  ];

  final notes = [
    Note(
      id: 'nt1',
      bookId: 'book1',
      chapterIndex: 3,
      paragraphIndex: 8,
      localOffset: 0.25,
      content: 'Моя заметка',
      highlightColor: '#FF5722',
      createdAt: DateTime.utc(2026, 7, 29, 15),
    ),
  ];

  test('buildBookExportJson produces valid JSON with all fields', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'Тестовая книга',
      highlights: highlights,
      bookmarks: bookmarks,
      notes: notes,
    );

    final encoded = jsonEncode(json);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded['book_id'] as String, 'book1');
    expect(decoded['title'] as String, 'Тестовая книга');
    expect(decoded['exported_at'] as String, isNotEmpty);
    expect(decoded['highlights'] as List, hasLength(2));
    expect(decoded['bookmarks'] as List, hasLength(1));
    expect(decoded['notes'] as List, hasLength(1));
  });

  test('highlights serialize all expected fields', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'T',
      highlights: highlights,
      bookmarks: [],
      notes: [],
    );

    final hl = (json['highlights'] as List)[0] as Map<String, dynamic>;
    expect(hl['id'], 'hl1');
    expect(hl['chapter_index'], 0);
    expect(hl['chapter_id'], 'ch1');
    expect(hl['block_index'], 2);
    expect(hl['start_offset'], 10);
    expect(hl['end_offset'], 30);
    expect(hl['selected_text'], 'Выделенный текст');
    expect(hl['color'], 'yellow');
    expect(hl['note'], 'Заметка к выделению');
    expect(hl['is_orphaned'], false);
    expect(hl['updated_at'], '2026-07-30T00:00:00.000Z');
  });

  test('highlights without updatedAt omit updated_at key', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'T',
      highlights: [highlights[1]],
      bookmarks: [],
      notes: [],
    );

    final hl = (json['highlights'] as List)[0] as Map<String, dynamic>;
    expect(hl.containsKey('updated_at'), false);
  });

  test('bookmarks serialize correctly', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'T',
      highlights: [],
      bookmarks: bookmarks,
      notes: [],
    );

    final bm = (json['bookmarks'] as List)[0] as Map<String, dynamic>;
    expect(bm['id'], 'bm1');
    expect(bm['chapter_index'], 2);
    expect(bm['paragraph_index'], 5);
    expect(bm['local_offset'], 0.75);
    expect(bm['selected_text'], 'Текст закладки');
    expect(bm['note'], 'Пометка');
  });

  test('notes serialize correctly', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'T',
      highlights: [],
      bookmarks: [],
      notes: notes,
    );

    final nt = (json['notes'] as List)[0] as Map<String, dynamic>;
    expect(nt['id'], 'nt1');
    expect(nt['chapter_index'], 3);
    expect(nt['paragraph_index'], 8);
    expect(nt['local_offset'], 0.25);
    expect(nt['content'], 'Моя заметка');
    expect(nt['highlight_color'], '#FF5722');
  });

  test('empty lists produce valid JSON with empty arrays', () {
    final json = buildBookExportJson(
      bookId: 'book1',
      title: 'Пустая книга',
      highlights: [],
      bookmarks: [],
      notes: [],
    );

    final encoded = jsonEncode(json);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded['highlights'] as List, isEmpty);
    expect(decoded['bookmarks'] as List, isEmpty);
    expect(decoded['notes'] as List, isEmpty);
    expect(decoded['book_id'] as String, 'book1');
    expect(decoded['title'] as String, 'Пустая книга');
  });

  test('export includes correct book_id and title', () {
    final json = buildBookExportJson(
      bookId: 'my-special-book-id',
      title: 'Война и мир',
      highlights: [],
      bookmarks: [],
      notes: [],
    );

    expect(json['book_id'], 'my-special-book-id');
    expect(json['title'], 'Война и мир');
  });

  test('buildBookExportFilename matches expected pattern', () {
    final filename = buildBookExportFilename('book123');

    expect(filename, startsWith('glibusta_export_book123_'));
    expect(filename, endsWith('.json'));
  });
}
