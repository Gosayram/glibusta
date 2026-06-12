// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_dao.dart';

// ignore_for_file: type=lint
mixin _$SeriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SeriesTable get series => attachedDatabase.series;
  $BookSeriesTable get bookSeries => attachedDatabase.bookSeries;
  SeriesDaoManager get managers => SeriesDaoManager(this);
}

class SeriesDaoManager {
  final _$SeriesDaoMixin _db;
  SeriesDaoManager(this._db);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db.attachedDatabase, _db.series);
  $$BookSeriesTableTableManager get bookSeries =>
      $$BookSeriesTableTableManager(_db.attachedDatabase, _db.bookSeries);
}
