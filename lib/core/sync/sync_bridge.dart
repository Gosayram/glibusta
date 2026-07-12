import 'dart:async';

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'powersync_adapter.dart';

/// Bridges writes between Drift and PowerSync tables.
///
/// When a row is written to a synced Drift table, [mirrorToPowerSync] copies
/// it to the corresponding PowerSync table so it can be uploaded to the cloud.
///
/// Currently a manual bridge — call the relevant method in your existing
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
      await _adapter.database!.put(
        'reading_progress',
        {
          'id': data.bookId,
          'book_id': data.bookId,
          'current_position': data.currentPosition,
          'chapter_index': data.chapterIndex,
          'paragraph_index': data.paragraphIndex,
          'local_offset': data.localOffset,
          'progress_percent': data.progressPercent,
          'chapter_id': data.chapterId,
          'text_offset': data.textOffset,
          'total_pages': data.totalPages,
          'last_read': data.lastRead.toIso8601String(),
          'updated_at': data.updatedAt.toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().warn(
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
      await _adapter.database!.put(
        'bookmarks',
        {
          'id': bookmark.id,
          'book_id': bookmark.bookId,
          'chapter_index': bookmark.chapterIndex,
          'paragraph_index': bookmark.paragraphIndex,
          'local_offset': bookmark.localOffset,
          'selected_text': bookmark.selectedText,
          'note': bookmark.note,
          'created_at': bookmark.createdAt.toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().warn(
        'SyncBridge: failed to mirror Bookmark: $e',
        name: 'Sync',
      );
    }
  }

  Future<void> deleteBookmark(String id) async {
    if (!_ready) return;
    try {
      await _adapter.database!.delete('bookmarks', id);
    } catch (e) {
      AppLogger().warn(
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
      await _adapter.database!.put(
        'notes',
        {
          'id': note.id,
          'book_id': note.bookId,
          'chapter_index': note.chapterIndex,
          'paragraph_index': note.paragraphIndex,
          'local_offset': note.localOffset,
          'content': note.content,
          'highlight_color': note.highlightColor,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': note.updatedAt?.toIso8601String(),
        },
      );
    } catch (e) {
      AppLogger().warn(
        'SyncBridge: failed to mirror Note: $e',
        name: 'Sync',
      );
    }
  }

  Future<void> deleteNote(String id) async {
    if (!_ready) return;
    try {
      await _adapter.database!.delete('notes', id);
    } catch (e) {
      AppLogger().warn(
        'SyncBridge: failed to delete Note: $e',
        name: 'Sync',
      );
    }
  }
}
