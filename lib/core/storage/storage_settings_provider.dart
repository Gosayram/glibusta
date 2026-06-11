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
  @override
  StorageMode build() {
    unawaited(_load());
    return StorageMode.internal;
  }

  Future<void> _load() async {
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    state = persistence.storageMode;
  }

  Future<void> updateMode(StorageMode mode) async {
    state = mode;
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    persistence.storageMode = mode;
  }
}

@Riverpod(keepAlive: true)
class ExternalFolderNotifier extends _$ExternalFolderNotifier {
  @override
  ({String? uri, String? name}) build() {
    unawaited(_load());
    return (uri: null, name: null);
  }

  Future<void> _load() async {
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    state = (uri: persistence.externalFolderUri, name: persistence.externalFolderName);
  }

  Future<void> updateFolder({required String uri, required String name}) async {
    state = (uri: uri, name: name);
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    persistence.externalFolderUri = uri;
    persistence.externalFolderName = name;
  }

  Future<void> clearFolder() async {
    state = (uri: null, name: null);
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    persistence.externalFolderUri = null;
    persistence.externalFolderName = null;
  }
}

@Riverpod(keepAlive: true)
class DirectReadNotifier extends _$DirectReadNotifier {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    state = persistence.directReadMode;
  }

  Future<void> update(bool value) async {
    state = value;
    final persistence = await ref.read(storageSettingsPersistenceProvider.future);
    persistence.directReadMode = value;
  }
}
