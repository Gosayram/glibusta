import 'dart:convert';

import '../../../core/database/app_database.dart';
import 'annotations_providers.dart';

enum AnnotationExportFormat { markdown, plainText, html, json }

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
      AnnotationExportFormat.html => AnnotationExport(
        filename: '$safeName-annotations.html',
        content: _html(annotations, bookTitle),
      ),
      AnnotationExportFormat.json => AnnotationExport(
        filename: '$safeName-annotations.json',
        content: _json(annotations, bookTitle),
      ),
    };
  }

  static String _markdown(AnnotationData annotations, String title) {
    final safeTitle = title.replaceAll(RegExp(r'[#*\[\]_~`>-]'), r'\\$&').replaceAll('\n', ' ');
    final buffer = StringBuffer('# Аннотации — $safeTitle\n\n');
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
      if (_hasText(item.selectedText)) {
        buffer.writeln('> ${item.selectedText!.replaceAll('\n', '\n> ')}\n');
      }
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
      buffer.writeln('> ${item.selectedText.replaceAll('\n', '\n> ')}\n');
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

  static String _html(AnnotationData annotations, String title) {
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="ru"><head><meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..writeln('<title>Аннотации — ${_escHtml(title)}</title>')
      ..writeln('<style>')
      ..writeln(
        'body{font-family:system-ui,sans-serif;max-width:48rem;margin:2rem auto;padding:0 1rem; '
        'color:#222;background:#fafafa;line-height:1.6}',
      )
      ..writeln('h1{border-bottom:2px solid #ddd;padding-bottom:.5rem}')
      ..writeln('h2{color:#555;margin-top:2rem}')
      ..writeln(
        '.card{background:#fff;border:1px solid #e0e0e0;border-radius:8px; '
        'padding:1rem;margin:.75rem 0;page-break-inside:avoid}',
      )
      ..writeln('.meta{font-size:.85rem;color:#888;margin-top:.5rem}')
      ..writeln(
        'blockquote{margin:.5rem 0;padding:.5rem 1rem;border-left:3px solid #ccc; '
        'background:#f5f5f5;border-radius:0 4px 4px 0}',
      )
      ..writeln('.note{color:#555;font-style:italic;margin-top:.4rem}')
      ..writeln('.hl{border-radius:2px;padding:1px 3px}')
      ..writeln('</style></head><body>')
      ..writeln('<h1>Аннотации — ${_escHtml(title)}</h1>');

    if (annotations.bookmarks.isNotEmpty) {
      buffer.writeln('<h2>Закладки</h2>');
      for (final b in annotations.bookmarks) {
        buffer.writeln('<div class="card">');
        if (_hasText(b.selectedText)) {
          final style = _highlightStyleAttr(b.highlightColor);
          buffer.writeln('<blockquote class="hl"$style>${_escHtml(b.selectedText!)}</blockquote>');
        }
        if (_hasText(b.note)) buffer.writeln('<p class="note">${_escHtml(b.note!)}</p>');
        buffer.writeln(
          '<div class="meta">${_escHtml(_anchor(b.chapterIndex, b.paragraphIndex, b.localOffset))}'
          ' &middot; ${b.createdAt.toIso8601String()}</div>',
        );
        buffer.writeln('</div>');
      }
    }

    if (annotations.notes.isNotEmpty) {
      buffer.writeln('<h2>Заметки</h2>');
      for (final n in annotations.notes) {
        buffer.writeln('<div class="card">');
        final style = _highlightStyleAttr(n.highlightColor);
        buffer.writeln('<p class="hl"$style>${_escHtml(n.content)}</p>');
        buffer.writeln(
          '<div class="meta">Цвет: ${_escHtml(n.highlightColor)}'
          ' &middot; ${_escHtml(_anchor(n.chapterIndex, n.paragraphIndex, n.localOffset))}'
          ' &middot; ${n.createdAt.toIso8601String()}</div>',
        );
        buffer.writeln('</div>');
      }
    }

    if (annotations.quotes.isNotEmpty) {
      buffer.writeln('<h2>Цитаты</h2>');
      for (final q in annotations.quotes) {
        buffer.writeln('<div class="card">');
        buffer.writeln('<blockquote>${_escHtml(q.selectedText)}</blockquote>');
        if (_hasText(q.note)) buffer.writeln('<p class="note">${_escHtml(q.note!)}</p>');
        buffer.writeln(
          '<div class="meta">${_escHtml(_anchor(q.chapterIndex, q.paragraphIndex))}'
          ' &middot; ${q.createdAt.toIso8601String()}</div>',
        );
        buffer.writeln('</div>');
      }
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static String _json(AnnotationData annotations, String title) {
    final annotationsList = <Map<String, Object?>>[];

    for (final b in annotations.bookmarks) {
      annotationsList.add({
        'type': 'bookmark',
        'text': b.selectedText,
        'note': b.note,
        'color': b.highlightColor,
        'style': b.highlightStyle,
        'book_id': b.bookId,
        'chapter': b.chapterIndex,
        'paragraph': b.paragraphIndex,
        'offset': b.localOffset,
        'created_at': b.createdAt.toIso8601String(),
      });
    }
    for (final n in annotations.notes) {
      annotationsList.add({
        'type': 'note',
        'text': n.content,
        'note': null,
        'color': n.highlightColor,
        'style': null,
        'book_id': n.bookId,
        'chapter': n.chapterIndex,
        'paragraph': n.paragraphIndex,
        'offset': n.localOffset,
        'created_at': n.createdAt.toIso8601String(),
      });
    }
    for (final q in annotations.quotes) {
      annotationsList.add({
        'type': 'quote',
        'text': q.selectedText,
        'note': q.note,
        'before_context': q.beforeContext,
        'after_context': q.afterContext,
        'color': null,
        'style': null,
        'book_id': q.bookId,
        'chapter': q.chapterIndex,
        'paragraph': q.paragraphIndex,
        'offset': null,
        'created_at': q.createdAt.toIso8601String(),
      });
    }

    final map = <String, Object?>{
      'version': '1.0',
      'book_title': title,
      'exported_at': DateTime.now().toIso8601String(),
      'annotations': annotationsList,
    };
    return jsonEncode(map);
  }

  static String _escHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _highlightStyleAttr(String? color) {
    if (color == null || color.isEmpty) return '';
    // Only allow #RRGGBB hex colors — prevents CSS injection from imported data
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) return '';
    return ' style="background-color:${color}20;border-left:3px solid $color"';
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
