import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_mode.dart';

part 'storage_settings_provider.g.dart';

const _kStorageMode = 'storage_mode';
const _kExternalFolderUri = 'external_folder_uri';
const _kExternalFolderName = 'external_folder_name';
const _kDirectReadMode = 'direct_read_mode';

@Riverpod(keepAlive: true)
class StorageModeNotifier extends _$StorageModeNotifier {
  var _version = 0;

  @override
  StorageMode build() {
    unawaited(_load());
    return StorageMode.downloads;
  }

  Future<void> _load() async {
    final version = _version;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    final index = prefs.getInt(_kStorageMode) ?? 0;
    state = StorageMode.values[index.clamp(0, StorageMode.values.length - 1)];
  }

  Future<void> updateMode(StorageMode mode) async {
    final version = ++_version;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    await prefs.setInt(_kStorageMode, mode.index);
  }
}

@Riverpod(keepAlive: true)
class ExternalFolderNotifier extends _$ExternalFolderNotifier {
  var _version = 0;

  @override
  ({String? uri, String? name}) build() {
    unawaited(_load());
    return (uri: null, name: null);
  }

  Future<void> _load() async {
    final version = _version;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    state = (
      uri: prefs.getString(_kExternalFolderUri),
      name: prefs.getString(_kExternalFolderName),
    );
  }

  Future<void> updateFolder({required String uri, required String name}) async {
    final version = ++_version;
    state = (uri: uri, name: name);
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    await prefs.setString(_kExternalFolderUri, uri);
    if (!ref.mounted || version != _version) return;
    await prefs.setString(_kExternalFolderName, name);
  }

  Future<void> clearFolder() async {
    final version = ++_version;
    state = (uri: null, name: null);
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    await prefs.remove(_kExternalFolderUri);
    if (!ref.mounted || version != _version) return;
    await prefs.remove(_kExternalFolderName);
  }
}

@Riverpod(keepAlive: true)
class DirectReadNotifier extends _$DirectReadNotifier {
  var _version = 0;

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    final version = _version;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    state = prefs.getBool(_kDirectReadMode) ?? false;
  }

  Future<void> update(bool value) async {
    final version = ++_version;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || version != _version) return;
    await prefs.setBool(_kDirectReadMode, value);
  }
}
