// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_time_dao.dart';

// ignore_for_file: type=lint
mixin _$ReadingTimeDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReadingTimeTable get readingTime => attachedDatabase.readingTime;
  ReadingTimeDaoManager get managers => ReadingTimeDaoManager(this);
}

class ReadingTimeDaoManager {
  final _$ReadingTimeDaoMixin _db;
  ReadingTimeDaoManager(this._db);
  $$ReadingTimeTableTableManager get readingTime =>
      $$ReadingTimeTableTableManager(_db.attachedDatabase, _db.readingTime);
}
