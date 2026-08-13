import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_settings_persistence.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('updateTapZoneWidth clamps to 0.1–0.5', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readerSettingsProvider, (_, _) {});
    addTearDown(subscription.close);

    container.read(readerSettingsProvider.notifier).updateTapZoneWidth(0.05);
    expect(container.read(readerSettingsProvider).tapZoneWidth, 0.1);

    container.read(readerSettingsProvider.notifier).updateTapZoneWidth(0.6);
    expect(container.read(readerSettingsProvider).tapZoneWidth, 0.5);

    container.read(readerSettingsProvider.notifier).updateTapZoneWidth(0.3);
    expect(container.read(readerSettingsProvider).tapZoneWidth, 0.3);
  });

  test('updateFullScreenMode changes mode', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readerSettingsProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(
      container.read(readerSettingsProvider).fullScreenMode,
      FullScreenMode.immersive,
    );

    container.read(readerSettingsProvider.notifier).updateFullScreenMode(FullScreenMode.keepPanels);
    expect(
      container.read(readerSettingsProvider).fullScreenMode,
      FullScreenMode.keepPanels,
    );

    container
        .read(readerSettingsProvider.notifier)
        .updateFullScreenMode(FullScreenMode.followSystem);
    expect(
      container.read(readerSettingsProvider).fullScreenMode,
      FullScreenMode.followSystem,
    );
  });

  test('tapZoneWidth and fullScreenMode persist', () async {
    SharedPreferences.setMockInitialValues({});
    const settings = ReaderSettings(
      tapZoneWidth: 0.4,
      fullScreenMode: FullScreenMode.keepPanels,
    );
    await ReaderSettingsPersistence.save(settings);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readerSettingsProvider, (_, _) {});
    addTearDown(subscription.close);

    container.read(readerSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final loaded = container.read(readerSettingsProvider);
    expect(loaded.tapZoneWidth, 0.4);
    expect(loaded.fullScreenMode, FullScreenMode.keepPanels);
  });
}
