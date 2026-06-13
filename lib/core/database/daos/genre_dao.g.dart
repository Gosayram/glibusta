// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genre_dao.dart';

// ignore_for_file: type=lint
mixin _$GenreDaoMixin on DatabaseAccessor<AppDatabase> {
  $GenresTable get genres => attachedDatabase.genres;
  GenreDaoManager get managers => GenreDaoManager(this);
}

class GenreDaoManager {
  final _$GenreDaoMixin _db;
  GenreDaoManager(this._db);
  $$GenresTableTableManager get genres =>
      $$GenresTableTableManager(_db.attachedDatabase, _db.genres);
}
