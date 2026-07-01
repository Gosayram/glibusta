// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'highlight_dao.dart';

// ignore_for_file: type=lint
mixin _$HighlightDaoMixin on DatabaseAccessor<AppDatabase> {
  $TextHighlightsTable get textHighlights => attachedDatabase.textHighlights;
  HighlightDaoManager get managers => HighlightDaoManager(this);
}

class HighlightDaoManager {
  final _$HighlightDaoMixin _db;
  HighlightDaoManager(this._db);
  $$TextHighlightsTableTableManager get textHighlights =>
      $$TextHighlightsTableTableManager(
        _db.attachedDatabase,
        _db.textHighlights,
      );
}
