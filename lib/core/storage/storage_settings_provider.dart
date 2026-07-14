import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_mode.dart';
import 'storage_settings_persistence.dart';

part 'storage_settings_provider.g.dart';

@Riverpod(keepAlive: true)
Future<StorageSettingsPersistence> storageSettingsPersistence(
  Ref ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  return StorageSettingsPersistence(prefs);
}

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
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    state = persistence.storageMode;
  }

  Future<void> updateMode(StorageMode mode) async {
    final version = ++_version;
    state = mode;
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    await persistence.saveStorageMode(mode);
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
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    state = (uri: persistence.externalFolderUri, name: persistence.externalFolderName);
  }

  Future<void> updateFolder({required String uri, required String name}) async {
    final version = ++_version;
    state = (uri: uri, name: name);
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    await persistence.saveExternalFolderUri(uri);
    if (!ref.mounted || version != _version) return;
    await persistence.saveExternalFolderName(name);
  }

  Future<void> clearFolder() async {
    final version = ++_version;
    state = (uri: null, name: null);
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    await persistence.saveExternalFolderUri(null);
    if (!ref.mounted || version != _version) return;
    await persistence.saveExternalFolderName(null);
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
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    state = persistence.directReadMode;
  }

  Future<void> update(bool value) async {
    final version = ++_version;
    state = value;
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    if (!ref.mounted || version != _version) return;
    await persistence.saveDirectReadMode(value);
  }
}
