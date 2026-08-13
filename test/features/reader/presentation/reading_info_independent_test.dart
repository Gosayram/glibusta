import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';
import 'package:glibusta/features/reader/presentation/reading_info_provider.dart';

void main() {
  group('independent header/footer slots', () {
    test('defaults have different header and footer values', () {
      const config = ReadingInfoModel.defaults;

      expect(config.headerLeft, InfoSlotMode.none);
      expect(config.headerCenter, InfoSlotMode.chapterTitle);
      expect(config.headerRight, InfoSlotMode.time);

      expect(config.footerLeft, InfoSlotMode.bookProgress);
      expect(config.footerCenter, InfoSlotMode.none);
      expect(config.footerRight, InfoSlotMode.chapterProgress);
    });

    test('updating header slot does not affect footer slot', () {
      const original = ReadingInfoModel.defaults;
      final updated = original.copyWith(headerLeft: InfoSlotMode.battery);

      expect(updated.headerLeft, InfoSlotMode.battery);
      expect(updated.footerLeft, original.footerLeft);
    });

    test('updating footer slot does not affect header slot', () {
      const original = ReadingInfoModel.defaults;
      final updated = original.copyWith(footerRight: InfoSlotMode.remainingBook);

      expect(updated.footerRight, InfoSlotMode.remainingBook);
      expect(updated.headerRight, original.headerRight);
    });

    test('all six slots can be set independently', () {
      const config = ReadingInfoModel(
        headerLeft: InfoSlotMode.wpm,
        headerCenter: InfoSlotMode.batteryAndTime,
        headerRight: InfoSlotMode.remainingChapter,
        footerLeft: InfoSlotMode.chapterTitle,
        footerCenter: InfoSlotMode.bookProgress,
        footerRight: InfoSlotMode.time,
      );

      expect(config.headerLeft, InfoSlotMode.wpm);
      expect(config.headerCenter, InfoSlotMode.batteryAndTime);
      expect(config.headerRight, InfoSlotMode.remainingChapter);
      expect(config.footerLeft, InfoSlotMode.chapterTitle);
      expect(config.footerCenter, InfoSlotMode.bookProgress);
      expect(config.footerRight, InfoSlotMode.time);
    });

    test('serialisation preserves independent header/footer values', () {
      const config = ReadingInfoModel(
        headerLeft: InfoSlotMode.battery,
        headerCenter: InfoSlotMode.none,
        headerRight: InfoSlotMode.remainingBook,
        footerLeft: InfoSlotMode.time,
        footerCenter: InfoSlotMode.chapterTitle,
        footerRight: InfoSlotMode.wpm,
      );

      final json = config.toJson();
      final restored = ReadingInfoModel.fromJson(json);

      expect(restored.headerLeft, InfoSlotMode.battery);
      expect(restored.headerRight, InfoSlotMode.remainingBook);
      expect(restored.footerLeft, InfoSlotMode.time);
      expect(restored.footerRight, InfoSlotMode.wpm);
    });

    test('reset restores independent defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(readingInfoProvider, (_, _) {});
      addTearDown(subscription.close);

      final notifier = container.read(readingInfoProvider.notifier);
      notifier.update(
        (s) => s.copyWith(
          headerLeft: InfoSlotMode.wpm,
          footerRight: InfoSlotMode.battery,
        ),
      );

      expect(container.read(readingInfoProvider).headerLeft, InfoSlotMode.wpm);
      expect(container.read(readingInfoProvider).footerRight, InfoSlotMode.battery);

      notifier.reset();

      final reset = container.read(readingInfoProvider);
      expect(reset.headerLeft, ReadingInfoModel.defaults.headerLeft);
      expect(reset.footerRight, ReadingInfoModel.defaults.footerRight);
    });

    test('provider update callback applies only the targeted slot', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingInfoProvider.notifier);
      notifier.update((s) => s.copyWith(headerCenter: InfoSlotMode.battery));

      final state = container.read(readingInfoProvider);
      expect(state.headerCenter, InfoSlotMode.battery);
      expect(state.footerCenter, ReadingInfoModel.defaults.footerCenter);
    });
  });
}
