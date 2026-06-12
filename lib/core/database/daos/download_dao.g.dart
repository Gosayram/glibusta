// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadDaoMixin on DatabaseAccessor<AppDatabase> {
  $DownloadsTable get downloads => attachedDatabase.downloads;
  DownloadDaoManager get managers => DownloadDaoManager(this);
}

class DownloadDaoManager {
  final _$DownloadDaoMixin _db;
  DownloadDaoManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db.attachedDatabase, _db.downloads);
}
