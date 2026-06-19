import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_database.dart';
import '../tables.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, BookTags, SavedBooks])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.attachedDatabase);

  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<Tag?> getTagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertTag(TagsCompanion tag) => into(tags).insertOnConflictUpdate(tag);

  Future<void> deleteTag(String id) async {
    await (delete(bookTags)..where((bt) => bt.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addBookToTag(String bookId, String tagId) async {
    await into(bookTags).insertOnConflictUpdate(
      BookTagsCompanion.insert(bookId: bookId, tagId: tagId),
    );
  }

  Future<void> removeBookFromTag(String bookId, String tagId) async {
    await (delete(bookTags)..where((bt) => bt.bookId.equals(bookId) & bt.tagId.equals(tagId))).go();
  }

  Future<List<Tag>> getTagsForBook(String bookId) async {
    final query = select(tags).join([
      innerJoin(bookTags, bookTags.tagId.equalsExp(tags.id)),
    ])..where(bookTags.bookId.equals(bookId));
    final results = await query.get();
    return results.map((row) => row.readTable(tags)).toList();
  }

  Stream<List<Tag>> watchTagsForBook(String bookId) {
    final query = select(tags).join([
      innerJoin(bookTags, bookTags.tagId.equalsExp(tags.id)),
    ])..where(bookTags.bookId.equals(bookId));
    return query.watch().map((rows) => rows.map((row) => row.readTable(tags)).toList());
  }

  Future<List<String>> getBookIdsWithTag(String tagId) async {
    final query = select(bookTags)..where((bt) => bt.tagId.equals(tagId));
    final results = await query.get();
    return results.map((bt) => bt.bookId).toList();
  }

  Future<List<String>> getBookIdsForTags(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];
    final query = select(bookTags)..where((bt) => bt.tagId.isIn(tagIds));
    final results = await query.get();
    return results.map((bt) => bt.bookId).toList();
  }

  Future<void> setBookTags(String bookId, List<String> tagIds) async {
    await transaction(() async {
      await (delete(bookTags)..where((bt) => bt.bookId.equals(bookId))).go();
      await attachedDatabase.batch((batch) {
        batch.insertAll(
          bookTags,
          tagIds
              .map((tagId) => BookTagsCompanion.insert(bookId: bookId, tagId: tagId))
              .toList(),
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }
}

final tagDaoProvider = Provider<TagDao>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tagDao;
});
