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

  group('GenreDao', () {
    test('insertGenre and getAllGenres', () async {
      await db.genreDao.insertGenre(
        GenresCompanion.insert(id: 'g1', name: 'Fiction'),
      );
      await db.genreDao.insertGenre(
        GenresCompanion.insert(id: 'g2', name: 'Science'),
      );
      final all = await db.genreDao.getAllGenres();
      expect(all.length, 2);
    });

    test('getAllGenres returns empty initially', () async {
      final all = await db.genreDao.getAllGenres();
      expect(all, isEmpty);
    });

    test('insertGenre upserts on conflict', () async {
      await db.genreDao.insertGenre(
        GenresCompanion.insert(id: 'g1', name: 'Old'),
      );
      await db.genreDao.insertGenre(
        GenresCompanion.insert(id: 'g1', name: 'New'),
      );
      final all = await db.genreDao.getAllGenres();
      expect(all.length, 1);
      expect(all.first.name, 'New');
    });
  });
}
