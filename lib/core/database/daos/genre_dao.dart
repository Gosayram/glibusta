import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'genre_dao.g.dart';

@DriftAccessor(tables: [Genres])
class GenreDao extends DatabaseAccessor<AppDatabase> with _$GenreDaoMixin {
  GenreDao(super.attachedDatabase);

  Future<List<Genre>> getAllGenres() async => select(genres).get();

  Future<int> insertGenre(GenresCompanion entry) => into(genres).insertOnConflictUpdate(entry);
}
