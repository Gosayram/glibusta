import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AuthorDao', () {
    test('insertAuthor and getAllAuthors', () async {
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a1', name: 'Author 1'),
      );
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a2', name: 'Author 2'),
      );
      final all = await db.authorDao.getAllAuthors();
      expect(all.length, 2);
    });

    test('getAuthorNamesByIds returns correct names', () async {
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a1', name: 'Tolstoy'),
      );
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a2', name: 'Dostoevsky'),
      );
      final names = await db.authorDao.getAuthorNamesByIds(['a1', 'a2']);
      expect(names, {'a1': 'Tolstoy', 'a2': 'Dostoevsky'});
    });

    test('getAuthorNamesByIds returns empty map for empty list', () async {
      final names = await db.authorDao.getAuthorNamesByIds([]);
      expect(names, isEmpty);
    });

    test('getAuthorNamesByIds ignores missing ids', () async {
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a1', name: 'Author 1'),
      );
      final names = await db.authorDao.getAuthorNamesByIds(['a1', 'missing']);
      expect(names.length, 1);
      expect(names['a1'], 'Author 1');
    });

    test('insertAuthor upserts on conflict', () async {
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a1', name: 'Old'),
      );
      await db.authorDao.insertAuthor(
        AuthorsCompanion.insert(id: 'a1', name: 'New'),
      );
      final names = await db.authorDao.getAuthorNamesByIds(['a1']);
      expect(names['a1'], 'New');
    });
  });
}
