import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'powersync_adapter.dart';

/// Bridges writes between Drift and PowerSync tables.
///
/// When a row is written to a synced Drift table, the mirror methods copy it
/// to the corresponding PowerSync table so it can be uploaded to the cloud.
///
/// Currently a manual bridge - call the relevant method in your existing
/// repository/write path. In a future phase this could be automated via
/// Drift migration callbacks or triggers.
class SyncBridge {
  final PowerSyncAdapter _adapter;

  SyncBridge(this._adapter);

  bool get _ready => _adapter.database != null && !_adapter.database!.closed;

  // ---------------------------------------------------------------------------
  // ReadingProgress
  // ---------------------------------------------------------------------------

  Future<void> mirrorReadingProgress(ReadingProgressData data) async {
    if (!_ready) return;
    try {
      await _adapter.database!.execute(
        '''
INSERT OR REPLACE INTO reading_progress
           (id, book_id, current_position, chapter_index, paragraph_index,
            local_offset, progress_percent, chapter_id, text_offset,
            total_pages, last_read, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          data.bookId,
          data.bookId,
          data.currentPosition,
          data.chapterIndex,
          data.paragraphIndex,
          data.localOffset,
          data.progressPercent,
          data.chapterId,
          data.textOffset,
          data.totalPages,
          data.lastRead.toIso8601String(),
          data.updatedAt.toIso8601String(),
        ],
      );
    } on Object catch (e) {
      AppLogger().warning(
        'SyncBridge: failed to mirror ReadingProgress: $e',
        name: 'Sync',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  Future<void> mirrorBookmark(Bookmark bookmark) async {
    if (!_ready) return;
    try {
      await _adapter.database!.execute(
        '''
INSERT OR REPLACE INTO bookmarks
           (id, book_id, chapter_index, paragraph_index, local_offset,
            selected_text, note, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          bookmark.id,
          bookmark.bookId,
          bookmark.chapterIndex,
          bookmark.paragraphIndex,
          bookmark.localOffset,
          bookmark.selectedText,
          bookmark.note,
          bookmark.createdAt.toIso8601String(),
        ],
      );
    } on Object catch (e) {
      AppLogger().warning(
        'SyncBridge: failed to mirror Bookmark: $e',
        name: 'Sync',
      );
    }
  }

  Future<void> deleteBookmark(String id) async {
    if (!_ready) return;
    try {
      await _adapter.database!.execute(
        'DELETE FROM bookmarks WHERE id = ?',
        [id],
      );
    } on Object catch (e) {
      AppLogger().warning(
        'SyncBridge: failed to delete Bookmark: $e',
        name: 'Sync',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<void> mirrorNote(Note note) async {
    if (!_ready) return;
    try {
      await _adapter.database!.execute(
        '''
INSERT OR REPLACE INTO notes
           (id, book_id, chapter_index, paragraph_index, local_offset,
            content, highlight_color, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          note.id,
          note.bookId,
          note.chapterIndex,
          note.paragraphIndex,
          note.localOffset,
          note.content,
          note.highlightColor,
          note.createdAt.toIso8601String(),
          note.updatedAt?.toIso8601String(),
        ],
      );
    } on Object catch (e) {
      AppLogger().warning(
        'SyncBridge: failed to mirror Note: $e',
        name: 'Sync',
      );
    }
  }

  Future<void> deleteNote(String id) async {
    if (!_ready) return;
    try {
      await _adapter.database!.execute(
        'DELETE FROM notes WHERE id = ?',
        [id],
      );
    } on Object catch (e) {
      AppLogger().warning(
        'SyncBridge: failed to delete Note: $e',
        name: 'Sync',
      );
    }
  }
}
