import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'author_dao.g.dart';

@DriftAccessor(tables: [Authors, SavedBooks])
class AuthorDao extends DatabaseAccessor<AppDatabase> with _$AuthorDaoMixin {
  AuthorDao(super.attachedDatabase);

  Stream<List<Author>> watchAll() => select(authors).watch();

  Future<List<Author>> getAllAuthors() async => select(authors).get();

  Future<int> insertAuthor(AuthorsCompanion entry) => into(authors).insertOnConflictUpdate(entry);

  Future<Map<String, String>> getAuthorNamesByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final query = select(authors)..where((t) => t.id.isIn(ids));
    final rows = await query.get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<List<Author>> getAuthorsForBook(String bookId) async {
    final book = await (select(savedBooks)..where((t) => t.id.equals(bookId))).getSingleOrNull();
    if (book == null) return [];
    final ids = book.authorIds;
    if (ids.isEmpty) return [];
    return (select(authors)..where((t) => t.id.isIn(ids))).get();
  }
}
