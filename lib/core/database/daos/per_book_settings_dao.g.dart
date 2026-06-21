// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'per_book_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$PerBookSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PerBookSettingsTable get perBookSettings => attachedDatabase.perBookSettings;
  PerBookSettingsDaoManager get managers => PerBookSettingsDaoManager(this);
}

class PerBookSettingsDaoManager {
  final _$PerBookSettingsDaoMixin _db;
  PerBookSettingsDaoManager(this._db);
  $$PerBookSettingsTableTableManager get perBookSettings => $$PerBookSettingsTableTableManager(
    _db.attachedDatabase,
    _db.perBookSettings,
  );
}
