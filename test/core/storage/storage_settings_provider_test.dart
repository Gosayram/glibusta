import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/storage/storage_mode.dart';
import 'package:glibusta/core/storage/storage_settings_persistence.dart';
import 'package:glibusta/core/storage/storage_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedUriPersistence extends StorageSettingsPersistence {
  _DelayedUriPersistence(super.prefs);

  final firstUriWriteStarted = Completer<void>();
  final allowFirstUriWrite = Completer<void>();
  final savedNames = <String?>[];
  var _uriWriteCount = 0;

  @override
  Future<void> saveExternalFolderUri(String? uri) {
    if (_uriWriteCount++ == 0) {
      firstUriWriteStarted.complete();
      return allowFirstUriWrite.future;
    }
    return Future.value();
  }

  @override
  Future<void> saveExternalFolderName(String? name) async {
    savedNames.add(name);
  }
}

void main() {
  test('a local storage-mode update wins over an in-flight initial load', () async {
    SharedPreferences.setMockInitialValues({'storage_mode': StorageMode.external.index});
    final prefs = await SharedPreferences.getInstance();
    final readyPersistence = Completer<StorageSettingsPersistence>();
    final container = ProviderContainer(
      overrides: [
        storageSettingsPersistenceProvider.overrideWith((ref) => readyPersistence.future),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(storageModeProvider.notifier);
    final update = notifier.updateMode(StorageMode.downloads);
    readyPersistence.complete(StorageSettingsPersistence(prefs));

    await update;

    expect(container.read(storageModeProvider), StorageMode.downloads);
    expect(prefs.getInt('storage_mode'), StorageMode.downloads.index);
  });

  test('does not persist a stale folder name after a newer folder update', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final persistence = _DelayedUriPersistence(prefs);
    final container = ProviderContainer(
      overrides: [
        storageSettingsPersistenceProvider.overrideWith((ref) async => persistence),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(externalFolderProvider.notifier);
    final firstUpdate = notifier.updateFolder(uri: 'content://old', name: 'Old folder');
    await persistence.firstUriWriteStarted.future;

    await notifier.clearFolder();
    persistence.allowFirstUriWrite.complete();
    await firstUpdate;

    expect(persistence.savedNames, [null]);
    expect(container.read(externalFolderProvider), (uri: null, name: null));
  });
}
