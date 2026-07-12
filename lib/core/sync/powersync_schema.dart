import 'package:powersync/powersync.dart';

/// PowerSync schema for synced tables.
///
/// Mirrors the Drift tables for ReadingProgress, Bookmarks, and Notes.
class PowerSyncSchemas {
  PowerSyncSchemas._();

  static final readingProgress = Table(
    'reading_progress',
    [
      const Column.text('book_id'),
      const Column.integer('current_position'),
      const Column.integer('chapter_index'),
      const Column.integer('paragraph_index'),
      const Column.real('local_offset'),
      const Column.real('progress_percent'),
      const Column.text('chapter_id'),
      const Column.integer('text_offset'),
      const Column.integer('total_pages'),
      const Column.text('last_read'),
      const Column.text('updated_at'),
    ],
    indexes: [
      Index.ascending('idx_rp_book_id', ['book_id']),
    ],
  );

  static final bookmarks = Table(
    'bookmarks',
    [
      const Column.text('book_id'),
      const Column.integer('chapter_index'),
      const Column.integer('paragraph_index'),
      const Column.real('local_offset'),
      const Column.text('selected_text'),
      const Column.text('note'),
      const Column.text('created_at'),
    ],
    indexes: [
      Index.ascending('idx_bm_book_id', ['book_id']),
    ],
  );

  static final notes = Table(
    'notes',
    [
      const Column.text('book_id'),
      const Column.integer('chapter_index'),
      const Column.integer('paragraph_index'),
      const Column.real('local_offset'),
      const Column.text('content'),
      const Column.text('highlight_color'),
      const Column.text('created_at'),
      const Column.text('updated_at'),
    ],
    indexes: [
      Index.ascending('idx_notes_book_id', ['book_id']),
    ],
  );

  static final schema = Schema(
    [readingProgress, bookmarks, notes],
  );
}
