import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/highlight_dao.dart';
import '../../../core/database/tables.dart';

class HighlightRepository {
  HighlightRepository(this._db);
  final AppDatabase _db;

  HighlightDao get _dao => _db.highlightDao;

  String computeChapterId(String title) {
    final bytes = utf8.encode(title.trim().toLowerCase());
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  Future<int> saveHighlight({
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required int blockIndex,
    required int startOffset,
    required int endOffset,
    required String selectedText,
    required String color,
    String? noteText,
  }) async {
    final id = '$bookId-${DateTime.now().millisecondsSinceEpoch}';
    return _dao.insertHighlight(
      TextHighlightsCompanion.insert(
        id: id,
        bookId: bookId,
        chapterId: chapterId,
        chapterIndex: chapterIndex,
        blockIndex: blockIndex,
        startOffset: startOffset,
        endOffset: endOffset,
        selectedText: selectedText,
        color: Value(color),
        noteText: Value(noteText),
      ),
    );
  }

  Future<void> updateNote(String highlightId, String noteText) async {
    await (_db.update(
      _db.textHighlights,
    )..where((TextHighlights t) => t.id.equals(highlightId))).write(
      TextHighlightsCompanion(
        noteText: Value(noteText),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateColor(String highlightId, String color) async {
    await (_db.update(
      _db.textHighlights,
    )..where((TextHighlights t) => t.id.equals(highlightId))).write(
      TextHighlightsCompanion(
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteHighlight(String id) => _dao.deleteHighlight(id);

  Future<void> deleteHighlightsForBook(String bookId) => _dao.deleteHighlightsForBook(bookId);

  Stream<List<TextHighlight>> watchHighlightsForBook(String bookId) =>
      _dao.watchHighlightsForBook(bookId);

  Stream<List<TextHighlight>> watchHighlightsByColor(
    String bookId,
    String color,
  ) => _dao.watchHighlightsByColor(bookId, color);

  Future<List<TextHighlight>> searchHighlights(
    String bookId,
    String query,
  ) => _dao.searchHighlights(bookId, query);

  Stream<List<TextHighlight>> watchHighlightsForChapter(
    String bookId,
    String chapterId,
  ) => _dao.watchHighlightsForChapter(bookId, chapterId);

  Future<List<TextHighlight>> getHighlightsForBook(String bookId) =>
      _dao.getHighlightsForBook(bookId);

  /// Re-anchor highlights after text reflow.
  ///
  /// For each highlight, attempts:
  /// 1. Exact match by chapterId + blockIndex + startOffset/endOffset
  /// 2. Fallback: search selectedText within the chapter's blocks
  /// 3. If no match found: mark as orphaned
  Future<List<TextHighlight>> reanchorHighlights({
    required String bookId,
    required Map<int, List<String>> chapterBlockTexts,
    required Map<int, String> chapterTitles,
  }) async {
    final highlights = await _dao.getHighlightsForBook(bookId);
    final results = <TextHighlight>[];

    for (final h in highlights) {
      final blockTexts = chapterBlockTexts[h.chapterIndex];
      if (blockTexts == null || blockTexts.isEmpty) {
        await _dao.markOrphaned(h.id);
        results.add(h.copyWith(isOrphaned: true));
        continue;
      }

      // Try exact match
      if (h.blockIndex < blockTexts.length) {
        final blockText = blockTexts[h.blockIndex];
        if (h.startOffset < blockText.length && h.endOffset <= blockText.length) {
          final actualText = blockText.substring(h.startOffset, h.endOffset);
          if (actualText == h.selectedText) {
            results.add(h);
            continue;
          }
        }
      }

      // Fallback: search selectedText in chapter
      final found = _findTextInChapter(
        blockTexts,
        h.selectedText,
        h.blockIndex,
      );
      if (found != null) {
        await (_db.update(
          _db.textHighlights,
        )..where((TextHighlights t) => t.id.equals(h.id))).write(
          TextHighlightsCompanion(
            blockIndex: Value(found.blockIndex),
            startOffset: Value(found.startOffset),
            endOffset: Value(found.endOffset),
            isOrphaned: const Value(false),
            updatedAt: Value<DateTime?>(DateTime.now()),
          ),
        );
        results.add(
          h.copyWith(
            blockIndex: found.blockIndex,
            startOffset: found.startOffset,
            endOffset: found.endOffset,
            isOrphaned: false,
            updatedAt: Value<DateTime?>(DateTime.now()),
          ),
        );
      } else {
        await _dao.markOrphaned(h.id);
        results.add(h.copyWith(isOrphaned: true));
      }
    }

    return results;
  }

  _ReanchorResult? _findTextInChapter(
    List<String> blockTexts,
    String selectedText,
    int preferredBlockIndex,
  ) {
    // Search from preferred block index outward
    final start = preferredBlockIndex.clamp(0, blockTexts.length - 1);
    final indices = <int>[start];
    for (var offset = 1; offset < blockTexts.length; offset++) {
      if (start - offset >= 0) indices.add(start - offset);
      if (start + offset < blockTexts.length) indices.add(start + offset);
    }

    for (final i in indices) {
      final pos = blockTexts[i].indexOf(selectedText);
      if (pos >= 0) {
        return _ReanchorResult(
          blockIndex: i,
          startOffset: pos,
          endOffset: pos + selectedText.length,
        );
      }
    }
    return null;
  }

  Future<String> exportToMarkdown(String bookId, {String? bookTitle}) async {
    final highlights = await getHighlightsForBook(bookId);
    final buf = StringBuffer();
    buf.writeln('# ${bookTitle ?? 'Книга'} — Выделения и заметки\n');

    var lastChapter = -1;
    for (final h in highlights) {
      if (h.chapterIndex != lastChapter) {
        lastChapter = h.chapterIndex;
        buf.writeln('---\n## Глава ${h.chapterIndex + 1}\n');
      }
      buf.writeln('> ${h.selectedText}\n');
      if (h.noteText != null && h.noteText!.isNotEmpty) {
        buf.writeln('*Заметка: ${h.noteText}*\n');
      }
    }

    return buf.toString();
  }

  Future<String> exportToTxt(String bookId) async {
    final md = await exportToMarkdown(bookId);
    return md.replaceAll(RegExp(r'[#*>-]'), '').trim();
  }
}

class _ReanchorResult {
  const _ReanchorResult({
    required this.blockIndex,
    required this.startOffset,
    required this.endOffset,
  });
  final int blockIndex;
  final int startOffset;
  final int endOffset;
}
