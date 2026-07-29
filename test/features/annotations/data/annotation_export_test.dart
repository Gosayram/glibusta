import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/annotations/data/annotation_export.dart';
import 'package:glibusta/features/annotations/data/annotations_providers.dart';

void main() {
  final annotations = AnnotationData(
    bookmarks: [
      Bookmark(
        id: 'bookmark',
        bookId: 'book',
        chapterIndex: 1,
        paragraphIndex: 2,
        localOffset: 0.43,
        selectedText: 'Текст закладки',
        note: 'Пометка',
        createdAt: DateTime.utc(2026, 7, 29),
      ),
    ],
    notes: [
      Note(
        id: 'note',
        bookId: 'book',
        chapterIndex: 3,
        paragraphIndex: 4,
        localOffset: 0.5,
        content: 'Собственная заметка',
        highlightColor: '#00FF00',
        createdAt: DateTime.utc(2026, 7, 29),
      ),
    ],
    quotes: [
      Quote(
        id: 'quote',
        bookId: 'book',
        chapterIndex: 5,
        paragraphIndex: 6,
        selectedText: 'Текст цитаты',
        note: 'Контекст',
        createdAt: DateTime.utc(2026, 7, 29),
      ),
    ],
  );

  test('Markdown export preserves annotations and semantic anchors', () {
    final export = AnnotationExportFormatter.build(
      annotations: annotations,
      format: AnnotationExportFormat.markdown,
      bookTitle: 'Книга: тест',
    );

    expect(export.filename, 'Книга_ тест-annotations.md');
    expect(export.content, contains('# Аннотации — Книга: тест'));
    expect(export.content, contains('глава 2, абзац 3, смещение 43%'));
    expect(export.content, contains('Текст закладки'));
    expect(export.content, contains('Пометка'));
    expect(export.content, contains('Цвет: #00FF00'));
    expect(export.content, contains('Текст цитаты'));
    expect(export.content, contains('глава 6, абзац 7'));
  });

  test('plain text export is portable and keeps optional metadata', () {
    final export = AnnotationExportFormatter.build(
      annotations: annotations,
      format: AnnotationExportFormat.plainText,
      bookTitle: 'Книга',
    );

    expect(export.filename, 'Книга-annotations.txt');
    expect(export.content, startsWith('АННОТАЦИИ — Книга'));
    expect(export.content, contains('ЗАКЛАДКИ'));
    expect(export.content, contains('ЗАМЕТКИ'));
    expect(export.content, contains('ЦИТАТЫ'));
    expect(export.content, contains('Цвет: #00FF00'));
    expect(export.content, contains('Создано: 2026-07-29T00:00:00.000Z'));
  });

  test('empty title has a safe local export filename', () {
    final export = AnnotationExportFormatter.build(
      annotations: const AnnotationData(bookmarks: [], notes: [], quotes: []),
      format: AnnotationExportFormat.markdown,
      bookTitle: '///',
    );

    expect(export.filename, '___-annotations.md');
  });
}
