import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_mode.dart';

const _kStorageMode = 'storage_mode';
const _kExternalFolderUri = 'external_folder_uri';
const _kExternalFolderName = 'external_folder_name';
const _kDirectReadMode = 'direct_read_mode';

class StorageSettingsPersistence {
  StorageSettingsPersistence(SharedPreferences prefs) : _prefs = prefs;

  final SharedPreferences _prefs;

  StorageMode get storageMode {
    final index = _prefs.getInt(_kStorageMode) ?? 0;
    return StorageMode.values[index.clamp(0, StorageMode.values.length - 1)];
  }

  Future<void> saveStorageMode(StorageMode mode) async {
    await _prefs.setInt(_kStorageMode, mode.index);
  }

  String? get externalFolderUri => _prefs.getString(_kExternalFolderUri);

  Future<void> saveExternalFolderUri(String? uri) async {
    if (uri != null) {
      await _prefs.setString(_kExternalFolderUri, uri);
    } else {
      await _prefs.remove(_kExternalFolderUri);
    }
  }

  String? get externalFolderName => _prefs.getString(_kExternalFolderName);

  Future<void> saveExternalFolderName(String? name) async {
    if (name != null) {
      await _prefs.setString(_kExternalFolderName, name);
    } else {
      await _prefs.remove(_kExternalFolderName);
    }
  }

  bool get directReadMode => _prefs.getBool(_kDirectReadMode) ?? false;

  Future<void> saveDirectReadMode(bool value) async {
    await _prefs.setBool(_kDirectReadMode, value);
  }

  Future<void> reset() async {
    await _prefs.remove(_kStorageMode);
    await _prefs.remove(_kExternalFolderUri);
    await _prefs.remove(_kExternalFolderName);
    await _prefs.remove(_kDirectReadMode);
  }
}
