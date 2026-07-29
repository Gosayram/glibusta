import '../../../core/database/app_database.dart';
import 'annotations_providers.dart';

enum AnnotationExportFormat { markdown, plainText }

/// A local, portable representation of the user's own annotations.
///
/// The export deliberately contains Glibusta's semantic anchor (chapter,
/// paragraph and local offset) instead of claiming compatibility with another
/// reader's annotation model.
class AnnotationExport {
  const AnnotationExport({
    required this.filename,
    required this.content,
  });

  final String filename;
  final String content;
}

class AnnotationExportFormatter {
  const AnnotationExportFormatter._();

  static AnnotationExport build({
    required AnnotationData annotations,
    required AnnotationExportFormat format,
    required String bookTitle,
  }) {
    final safeName = _safeFilename(bookTitle);
    return switch (format) {
      AnnotationExportFormat.markdown => AnnotationExport(
        filename: '$safeName-annotations.md',
        content: _markdown(annotations, bookTitle),
      ),
      AnnotationExportFormat.plainText => AnnotationExport(
        filename: '$safeName-annotations.txt',
        content: _plainText(annotations, bookTitle),
      ),
    };
  }

  static String _markdown(AnnotationData annotations, String title) {
    final buffer = StringBuffer('# Аннотации — $title\n\n');
    _writeMarkdownBookmarks(buffer, annotations.bookmarks);
    _writeMarkdownNotes(buffer, annotations.notes);
    _writeMarkdownQuotes(buffer, annotations.quotes);
    return buffer.toString();
  }

  static void _writeMarkdownBookmarks(StringBuffer buffer, List<Bookmark> items) {
    if (items.isEmpty) return;
    buffer.writeln('## Закладки\n');
    for (final item in items) {
      buffer.writeln('### ${_anchor(item.chapterIndex, item.paragraphIndex, item.localOffset)}');
      if (_hasText(item.selectedText)) buffer.writeln('> ${item.selectedText}\n');
      if (_hasText(item.note)) buffer.writeln('**Заметка:** ${item.note}\n');
      buffer.writeln('_Создано: ${item.createdAt.toIso8601String()}_\n');
    }
  }

  static void _writeMarkdownNotes(StringBuffer buffer, List<Note> items) {
    if (items.isEmpty) return;
    buffer.writeln('## Заметки\n');
    for (final item in items) {
      buffer.writeln('### ${_anchor(item.chapterIndex, item.paragraphIndex, item.localOffset)}');
      buffer.writeln('${item.content}\n');
      buffer.writeln(
        '_Цвет: ${item.highlightColor}; создано: ${item.createdAt.toIso8601String()}_\n',
      );
    }
  }

  static void _writeMarkdownQuotes(StringBuffer buffer, List<Quote> items) {
    if (items.isEmpty) return;
    buffer.writeln('## Цитаты\n');
    for (final item in items) {
      buffer.writeln('### ${_anchor(item.chapterIndex, item.paragraphIndex)}');
      buffer.writeln('> ${item.selectedText}\n');
      if (_hasText(item.note)) buffer.writeln('**Заметка:** ${item.note}\n');
      buffer.writeln('_Создано: ${item.createdAt.toIso8601String()}_\n');
    }
  }

  static String _plainText(AnnotationData annotations, String title) {
    final buffer = StringBuffer('АННОТАЦИИ — $title\n\n');
    _writePlainBookmarks(buffer, annotations.bookmarks);
    _writePlainNotes(buffer, annotations.notes);
    _writePlainQuotes(buffer, annotations.quotes);
    return buffer.toString();
  }

  static void _writePlainBookmarks(StringBuffer buffer, List<Bookmark> items) {
    if (items.isEmpty) return;
    buffer.writeln('ЗАКЛАДКИ');
    for (final item in items) {
      buffer.writeln(_anchor(item.chapterIndex, item.paragraphIndex, item.localOffset));
      if (_hasText(item.selectedText)) buffer.writeln(item.selectedText);
      if (_hasText(item.note)) buffer.writeln('Заметка: ${item.note}');
      buffer.writeln('Создано: ${item.createdAt.toIso8601String()}\n');
    }
  }

  static void _writePlainNotes(StringBuffer buffer, List<Note> items) {
    if (items.isEmpty) return;
    buffer.writeln('ЗАМЕТКИ');
    for (final item in items) {
      buffer.writeln(_anchor(item.chapterIndex, item.paragraphIndex, item.localOffset));
      buffer.writeln(item.content);
      buffer.writeln('Цвет: ${item.highlightColor}');
      buffer.writeln('Создано: ${item.createdAt.toIso8601String()}\n');
    }
  }

  static void _writePlainQuotes(StringBuffer buffer, List<Quote> items) {
    if (items.isEmpty) return;
    buffer.writeln('ЦИТАТЫ');
    for (final item in items) {
      buffer.writeln(_anchor(item.chapterIndex, item.paragraphIndex));
      buffer.writeln(item.selectedText);
      if (_hasText(item.note)) buffer.writeln('Заметка: ${item.note}');
      buffer.writeln('Создано: ${item.createdAt.toIso8601String()}\n');
    }
  }

  static String _anchor(int chapterIndex, int paragraphIndex, [double? localOffset]) {
    final position = 'глава ${chapterIndex + 1}, абзац ${paragraphIndex + 1}';
    if (localOffset == null) return position;
    return '$position, смещение ${(localOffset * 100).round()}%';
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

  static String _safeFilename(String title) {
    final value = title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
    return value.isEmpty ? 'annotations' : value;
  }
}
