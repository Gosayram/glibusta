import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/connectivity/offline_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a local mobile-download policy update wins over the initial load', () async {
    SharedPreferences.setMockInitialValues({'allow_mobile_downloads': false});
    final prefs = await SharedPreferences.getInstance();
    final persistence = Completer<DownloadPolicyPersistence>();
    final container = ProviderContainer(
      overrides: [
        downloadPolicyPersistenceProvider.overrideWith((ref) => persistence.future),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(allowMobileDownloadsProvider.notifier);
    final update = notifier.update(true);
    persistence.complete(DownloadPolicyPersistence(prefs));

    await update;

    expect(container.read(allowMobileDownloadsProvider), isTrue);
    expect(prefs.getBool('allow_mobile_downloads'), isTrue);
  });

  test('a local Wi-Fi resume policy update wins over the initial load', () async {
    SharedPreferences.setMockInitialValues({'auto_resume_on_wifi': true});
    final prefs = await SharedPreferences.getInstance();
    final persistence = Completer<DownloadPolicyPersistence>();
    final container = ProviderContainer(
      overrides: [
        downloadPolicyPersistenceProvider.overrideWith((ref) => persistence.future),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(autoResumeOnWifiProvider.notifier);
    final update = notifier.update(false);
    persistence.complete(DownloadPolicyPersistence(prefs));

    await update;

    expect(container.read(autoResumeOnWifiProvider), isFalse);
    expect(prefs.getBool('auto_resume_on_wifi'), isFalse);
  });
}
