import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_mode.dart';

const _kStorageMode = 'storage_mode';
const _kExternalFolderUri = 'external_folder_uri';
const _kExternalFolderName = 'external_folder_name';
const _kDirectReadMode = 'direct_read_mode';

class StorageSettingsPersistence {
  StorageSettingsPersistence(this._prefs);

  final SharedPreferences _prefs;

  StorageMode get storageMode {
    final index = _prefs.getInt(_kStorageMode) ?? 0;
    return StorageMode.values[index.clamp(0, StorageMode.values.length - 1)];
  }

  set storageMode(StorageMode mode) {
    unawaited(_prefs.setInt(_kStorageMode, mode.index));
  }

  String? get externalFolderUri => _prefs.getString(_kExternalFolderUri);

  set externalFolderUri(String? uri) {
    if (uri != null) {
      unawaited(_prefs.setString(_kExternalFolderUri, uri));
    } else {
      unawaited(_prefs.remove(_kExternalFolderUri));
    }
  }

  String? get externalFolderName => _prefs.getString(_kExternalFolderName);

  set externalFolderName(String? name) {
    if (name != null) {
      unawaited(_prefs.setString(_kExternalFolderName, name));
    } else {
      unawaited(_prefs.remove(_kExternalFolderName));
    }
  }

  bool get directReadMode => _prefs.getBool(_kDirectReadMode) ?? false;

  set directReadMode(bool value) {
    unawaited(_prefs.setBool(_kDirectReadMode, value));
  }

  Future<void> reset() async {
    await _prefs.remove(_kStorageMode);
    await _prefs.remove(_kExternalFolderUri);
    await _prefs.remove(_kExternalFolderName);
    await _prefs.remove(_kDirectReadMode);
  }
}
