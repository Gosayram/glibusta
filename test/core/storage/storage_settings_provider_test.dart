import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/storage/storage_mode.dart';
import 'package:glibusta/core/storage/storage_settings_persistence.dart';
import 'package:glibusta/core/storage/storage_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
