import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/features/reader/data/auto_theme_service.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReaderController cached settings', () {
    test('effectiveMode reflects initial settings', () {
      final container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(AppLogger()),
          autoThemeServiceProvider.overrideWithValue(AutoThemeService()),
          readerSettingsProvider.overrideWith(
            () => _TestReaderSettingsNotifier(
              const ReaderSettings(mode: ReaderMode.focus),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      late ReaderController controller;
      final sub = container.listen(
        _controllerProvider,
        (_, next) => controller = next,
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(controller.effectiveMode, ReaderMode.focus);
    });

    test('effectiveMode updates when settings change', () {
      final notifier = _TestReaderSettingsNotifier(
        const ReaderSettings(),
      );
      final container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(AppLogger()),
          autoThemeServiceProvider.overrideWithValue(AutoThemeService()),
          readerSettingsProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      late ReaderController controller;
      final sub = container.listen(
        _controllerProvider,
        (_, next) => controller = next,
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(controller.effectiveMode, ReaderMode.paginated);

      container.read(readerSettingsProvider.notifier).updateMode(ReaderMode.continuous);
      expect(controller.effectiveMode, ReaderMode.continuous);

      container.read(readerSettingsProvider.notifier).updateMode(ReaderMode.focus);
      expect(controller.effectiveMode, ReaderMode.focus);
    });

    test('cached eink flag updates when settings change', () {
      final notifier = _TestReaderSettingsNotifier(
        const ReaderSettings(),
      );
      final container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(AppLogger()),
          autoThemeServiceProvider.overrideWithValue(AutoThemeService()),
          readerSettingsProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      late ReaderController controller;
      final sub = container.listen(
        _controllerProvider,
        (_, next) => controller = next,
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(controller.effectiveMode, ReaderMode.paginated);

      container.read(readerSettingsProvider.notifier).updateEink(true);
      expect(controller.effectiveMode, ReaderMode.paginated);
    });

    test('cached twoPageEnabled updates when settings change', () {
      final notifier = _TestReaderSettingsNotifier(
        const ReaderSettings(),
      );
      final container = ProviderContainer(
        overrides: [
          appLoggerProvider.overrideWithValue(AppLogger()),
          autoThemeServiceProvider.overrideWithValue(AutoThemeService()),
          readerSettingsProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        _controllerProvider,
        (_, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      container.read(readerSettingsProvider.notifier).updateTwoPageEnabled(true);
      expect(
        container.read(readerSettingsProvider).twoPageEnabled,
        isTrue,
      );
    });
  });
}

final _controllerProvider = Provider<ReaderController>((ref) {
  return ReaderController('test-book', ref);
});

class _TestReaderSettingsNotifier extends ReaderSettingsNotifier {
  _TestReaderSettingsNotifier(this._initial);
  final ReaderSettings _initial;

  @override
  ReaderSettings build() => _initial;
}
