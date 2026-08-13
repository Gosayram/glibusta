import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'highlight_dao.g.dart';

@DriftAccessor(tables: [TextHighlights])
class HighlightDao extends DatabaseAccessor<AppDatabase> with _$HighlightDaoMixin {
  HighlightDao(super.attachedDatabase);

  Future<List<TextHighlight>> getHighlightsForBook(String bookId) async =>
      (select(textHighlights)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.chapterIndex),
              (t) => OrderingTerm.asc(t.blockIndex),
            ]))
          .get();

  Stream<List<TextHighlight>> watchHighlightsForBook(String bookId) =>
      (select(textHighlights)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.chapterIndex),
              (t) => OrderingTerm.asc(t.blockIndex),
            ]))
          .watch();

  Stream<List<TextHighlight>> watchHighlightsByColor(
    String bookId,
    String color,
  ) =>
      (select(textHighlights)
            ..where((t) => t.bookId.equals(bookId) & t.color.equals(color))
            ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
          .watch();

  Future<List<TextHighlight>> searchHighlights(
    String bookId,
    String query,
  ) async {
    // ponytail: escape LIKE meta-characters so "100%" doesn't match "1000"
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    return (select(textHighlights)
          ..where(
            (t) =>
                t.bookId.equals(bookId) &
                (t.selectedText.like(pattern, escapeChar: r'\') |
                    t.noteText.like(pattern, escapeChar: r'\')),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.chapterIndex)]))
        .get();
  }

  Stream<List<TextHighlight>> watchHighlightsForChapter(
    String bookId,
    String chapterId,
  ) =>
      (select(textHighlights)
            ..where(
              (t) => t.bookId.equals(bookId) & t.chapterId.equals(chapterId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.blockIndex)]))
          .watch();

  Future<int> insertHighlight(TextHighlightsCompanion highlight) =>
      into(textHighlights).insert(highlight);

  Future<bool> updateHighlight(TextHighlightsCompanion highlight) =>
      update(textHighlights).replace(highlight);

  Future<int> deleteHighlight(String id) =>
      (delete(textHighlights)..where((t) => t.id.equals(id))).go();

  Future<int> deleteHighlightsForBook(String bookId) =>
      (delete(textHighlights)..where((t) => t.bookId.equals(bookId))).go();

  Future<int> markOrphaned(String id) =>
      (update(textHighlights)..where((t) => t.id.equals(id))).write(
        TextHighlightsCompanion(
          isOrphaned: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
