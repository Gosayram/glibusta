import '../../../core/database/app_database.dart';

Map<String, dynamic> buildBookExportJson({
  required String bookId,
  required String title,
  required List<TextHighlight> highlights,
  required List<Bookmark> bookmarks,
  required List<Note> notes,
}) {
  return {
    'book_id': bookId,
    'title': title,
    'exported_at': DateTime.now().toIso8601String(),
    'highlights': highlights
        .map(
          (h) => {
            'id': h.id,
            'chapter_index': h.chapterIndex,
            'chapter_id': h.chapterId,
            'block_index': h.blockIndex,
            'start_offset': h.startOffset,
            'end_offset': h.endOffset,
            'selected_text': h.selectedText,
            'color': h.color,
            'note': h.noteText,
            'is_orphaned': h.isOrphaned,
            'created_at': h.createdAt.toIso8601String(),
            if (h.updatedAt != null) 'updated_at': h.updatedAt!.toIso8601String(),
          },
        )
        .toList(),
    'bookmarks': bookmarks
        .map(
          (b) => {
            'id': b.id,
            'chapter_index': b.chapterIndex,
            'paragraph_index': b.paragraphIndex,
            'local_offset': b.localOffset,
            'selected_text': b.selectedText,
            'note': b.note,
            'created_at': b.createdAt.toIso8601String(),
          },
        )
        .toList(),
    'notes': notes
        .map(
          (n) => {
            'id': n.id,
            'chapter_index': n.chapterIndex,
            'paragraph_index': n.paragraphIndex,
            'local_offset': n.localOffset,
            'content': n.content,
            'highlight_color': n.highlightColor,
            'created_at': n.createdAt.toIso8601String(),
            if (n.updatedAt != null) 'updated_at': n.updatedAt!.toIso8601String(),
          },
        )
        .toList(),
  };
}

String buildBookExportFilename(String bookId) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'glibusta_export_${bookId}_$ts.json';
}

String buildBookExportHtmlFilename(String bookId) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'glibusta_export_${bookId}_$ts.html';
}

String buildBookExportTxtFilename(String bookId) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'glibusta_export_${bookId}_$ts.txt';
}

String buildBookExportMdFilename(String bookId) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'glibusta_export_${bookId}_$ts.md';
}

String buildBookExportTxt({
  required String bookTitle,
  required List<TextHighlight> highlights,
  required List<Bookmark> bookmarks,
  required List<Note> notes,
}) {
  final buf = StringBuffer()
    ..writeln('Экспорт данных: $bookTitle')
    ..writeln('=' * 32)
    ..writeln();

  if (highlights.isNotEmpty) {
    buf
      ..writeln('ВЫДЕЛЕНИЯ')
      ..writeln('-' * 9);
    for (final h in highlights) {
      buf
        ..writeln('${h.color} | Стр. ${h.chapterIndex + 1} | ${h.createdAt.toIso8601String()}')
        ..writeln('"${h.selectedText}"');
      if (h.noteText != null && h.noteText!.trim().isNotEmpty) {
        buf.writeln('Заметка: ${h.noteText}');
      }
      buf.writeln();
    }
  }

  if (bookmarks.isNotEmpty) {
    buf
      ..writeln('ЗАКЛАДКИ')
      ..writeln('-' * 9);
    for (final b in bookmarks) {
      buf.writeln('Стр. ${b.chapterIndex + 1} | ${b.createdAt.toIso8601String()}');
      if (b.selectedText != null && b.selectedText!.trim().isNotEmpty) {
        buf.writeln('Текст: ${b.selectedText}');
      }
      buf.writeln();
    }
  }

  if (notes.isNotEmpty) {
    buf
      ..writeln('ЗАМЕТКИ')
      ..writeln('-' * 8);
    for (final n in notes) {
      buf
        ..writeln('Стр. ${n.chapterIndex + 1} | ${n.createdAt.toIso8601String()}')
        ..writeln(n.content)
        ..writeln();
    }
  }

  return buf.toString();
}

String buildBookExportMarkdown({
  required String bookTitle,
  required List<TextHighlight> highlights,
  required List<Bookmark> bookmarks,
  required List<Note> notes,
}) {
  final buf = StringBuffer()
    ..writeln('# Экспорт данных: $bookTitle')
    ..writeln();

  if (highlights.isNotEmpty) {
    buf.writeln('## Выделения');
    for (final h in highlights) {
      buf
        ..writeln()
        ..writeln(
          '- **${h.color}** | Стр. ${h.chapterIndex + 1} | '
          '${h.createdAt.toIso8601String()}',
        )
        ..writeln('> "${h.selectedText}"');
      if (h.noteText != null && h.noteText!.trim().isNotEmpty) {
        buf.writeln('*Заметка: ${h.noteText}*');
      }
    }
    buf.writeln();
  }

  if (bookmarks.isNotEmpty) {
    buf.writeln('## Закладки');
    for (final b in bookmarks) {
      buf
        ..writeln()
        ..writeln(
          '- Стр. ${b.chapterIndex + 1} | ${b.createdAt.toIso8601String()}',
        );
      if (b.selectedText != null && b.selectedText!.trim().isNotEmpty) {
        buf.writeln('> ${b.selectedText}');
      }
    }
    buf.writeln();
  }

  if (notes.isNotEmpty) {
    buf.writeln('## Заметки');
    for (final n in notes) {
      buf
        ..writeln()
        ..writeln(
          '- Стр. ${n.chapterIndex + 1} | ${n.createdAt.toIso8601String()}',
        )
        ..writeln(n.content);
    }
    buf.writeln();
  }

  return buf.toString();
}

String buildBookExportHtml({
  required String bookTitle,
  required List<TextHighlight> highlights,
  required List<Bookmark> bookmarks,
  required List<Note> notes,
}) {
  final buf = StringBuffer()
    ..write('<!DOCTYPE html>')
    ..write('<html lang="ru"><head><meta charset="utf-8">')
    ..write('<title>${_esc(bookTitle)}</title>')
    ..write(_css())
    ..write('</head><body>')
    ..write('<h1>${_esc(bookTitle)}</h1>');

  if (highlights.isNotEmpty) {
    buf
      ..write('<section><h2>Выделения</h2>')
      ..write('<ul class="items">');
    for (final h in highlights) {
      buf
        ..write('<li>')
        ..write(
          '<span class="hl" style="background-color:${_esc(h.color)}">'
          '${_esc(h.selectedText)}</span>',
        );
      if (h.noteText != null && h.noteText!.trim().isNotEmpty) {
        buf.write('<div class="note">${_esc(h.noteText!)}</div>');
      }
      buf
        ..write('<time>${_esc(h.createdAt.toIso8601String())}</time>')
        ..write('</li>');
    }
    buf.write('</ul></section>');
  }

  if (bookmarks.isNotEmpty) {
    buf
      ..write('<section><h2>Закладки</h2>')
      ..write('<ul class="items">');
    for (final b in bookmarks) {
      buf
        ..write('<li>')
        ..write(
          '<span class="anchor">Глава ${b.chapterIndex + 1}, '
          'абзац ${b.paragraphIndex + 1}</span>',
        );
      if (b.selectedText != null && b.selectedText!.trim().isNotEmpty) {
        buf.write('<blockquote>${_esc(b.selectedText!)}</blockquote>');
      }
      if (b.note != null && b.note!.trim().isNotEmpty) {
        buf.write('<div class="note">${_esc(b.note!)}</div>');
      }
      buf
        ..write('<time>${_esc(b.createdAt.toIso8601String())}</time>')
        ..write('</li>');
    }
    buf.write('</ul></section>');
  }

  if (notes.isNotEmpty) {
    buf
      ..write('<section><h2>Заметки</h2>')
      ..write('<ul class="items">');
    for (final n in notes) {
      buf
        ..write('<li>')
        ..write(
          '<span class="anchor">Глава ${n.chapterIndex + 1}, '
          'абзац ${n.paragraphIndex + 1}</span>',
        )
        ..write('<div class="content">${_esc(n.content)}</div>')
        ..write(
          '<time>${_esc(n.createdAt.toIso8601String())}</time>',
        )
        ..write('</li>');
    }
    buf.write('</ul></section>');
  }

  buf.write('</body></html>');
  return buf.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _css() =>
    '<style>'
    'body{font-family:Georgia,serif;max-width:800px;margin:0 auto; '
    'padding:20px;line-height:1.6;color:#222} '
    'h1{border-bottom:2px solid #444;padding-bottom:8px} '
    'h2{color:#555;margin-top:32px} '
    '.items{list-style:none;padding:0} '
    '.items li{margin-bottom:16px;padding:12px;border:1px solid #ddd; '
    'border-radius:4px} '
    '.hl{padding:2px 4px;border-radius:2px} '
    'blockquote{margin:8px 0 0;padding:8px 12px;border-left:3px solid #ccc; '
    'color:#555;font-style:italic} '
    '.note{margin-top:6px;color:#666;font-size:0.95em} '
    '.anchor{font-size:0.85em;color:#888} '
    '.content{margin-top:4px} '
    'time{display:block;font-size:0.8em;color:#999;margin-top:4px} '
    '</style>';
