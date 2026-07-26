import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reader_settings_persistence.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('applying a per-book profile does not replace global reader settings', () async {
    SharedPreferences.setMockInitialValues({});
    const global = ReaderSettings(theme: ReaderTheme.paper);
    const perBook = ReaderSettings(theme: ReaderTheme.bedtime, fontSize: 24);
    await ReaderSettingsPersistence.save(global);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(readerSettingsProvider, (_, _) {});
    addTearDown(subscription.close);

    container.read(readerSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    container.read(readerSettingsProvider.notifier).applyProfile(perBook);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(await ReaderSettingsPersistence.load(), global);
  });
}
