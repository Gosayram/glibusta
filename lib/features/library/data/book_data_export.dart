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
