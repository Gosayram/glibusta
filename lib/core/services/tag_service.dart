import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

const _uuid = Uuid();

class TagService {
  TagService(this._db);

  final AppDatabase _db;

  Future<Tag> createTag(String name, {String color = '#2196F3'}) async {
    final id = _uuid.v4();
    final tag = TagsCompanion.insert(id: id, name: name, color: Value(color));
    await _db.tagDao.insertTag(tag);
    return _db.tagDao.getTagById(id).then((t) => t!);
  }

  Future<void> deleteTag(String id) => _db.tagDao.deleteTag(id);

  Future<void> renameTag(String id, String newName) async {
    final existing = await _db.tagDao.getTagById(id);
    if (existing == null) return;
    await _db.tagDao.insertTag(
      TagsCompanion(
        id: Value(id),
        name: Value(newName),
        color: Value(existing.color),
      ),
    );
  }

  Future<void> changeTagColor(String id, String newColor) async {
    final existing = await _db.tagDao.getTagById(id);
    if (existing == null) return;
    await _db.tagDao.insertTag(
      TagsCompanion(
        id: Value(id),
        name: Value(existing.name),
        color: Value(newColor),
      ),
    );
  }

  Future<List<Tag>> getAllTags() => _db.tagDao.getAllTags();

  Stream<List<Tag>> watchAllTags() => _db.tagDao.watchAllTags();

  Future<List<Tag>> getTagsForBook(String bookId) => _db.tagDao.getTagsForBook(bookId);

  Stream<List<Tag>> watchTagsForBook(String bookId) => _db.tagDao.watchTagsForBook(bookId);

  Future<void> setBookTags(String bookId, List<String> tagIds) =>
      _db.tagDao.setBookTags(bookId, tagIds);

  Future<void> addBookToTag(String bookId, String tagId) => _db.tagDao.addBookToTag(bookId, tagId);

  Future<void> removeBookFromTag(String bookId, String tagId) =>
      _db.tagDao.removeBookFromTag(bookId, tagId);

  Future<List<String>> getBookIdsWithTag(String tagId) => _db.tagDao.getBookIdsWithTag(tagId);
}

final tagServiceProvider = Provider<TagService>((ref) {
  final db = ref.watch(databaseProvider);
  return TagService(db);
});

final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  final service = ref.watch(tagServiceProvider);
  return service.watchAllTags();
});
