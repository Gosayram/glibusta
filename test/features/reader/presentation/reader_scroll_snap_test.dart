import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderSettings.scrollSnap', () {
    test('defaults to false', () {
      const settings = ReaderSettings();
      expect(settings.scrollSnap, isFalse);
    });

    test('copyWith sets scrollSnap to true', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(scrollSnap: true);
      expect(updated.scrollSnap, isTrue);
    });

    test('copyWith sets scrollSnap to false', () {
      const settings = ReaderSettings(scrollSnap: true);
      final updated = settings.copyWith(scrollSnap: false);
      expect(updated.scrollSnap, isFalse);
    });

    test('copyWith preserves scrollSnap when not specified', () {
      const settings = ReaderSettings(scrollSnap: true);
      final updated = settings.copyWith(fontSize: 24.0);
      expect(updated.scrollSnap, isTrue);
    });
  });

  group('Continuous mode scroll physics with scrollSnap', () {
    test('scrollSnap is independent of mode', () {
      const settings = ReaderSettings(
        mode: ReaderMode.continuous,
        scrollSnap: true,
      );
      expect(settings.mode, ReaderMode.continuous);
      expect(settings.scrollSnap, isTrue);
    });

    test('scrollSnap works with all scroll inertia values', () {
      for (final inertia in ScrollInertia.values) {
        final settings = ReaderSettings(
          mode: ReaderMode.continuous,
          scrollSnap: true,
          scrollInertia: inertia,
        );
        expect(settings.scrollSnap, isTrue);
        expect(settings.scrollInertia, inertia);
      }
    });

    test('scrollSnap false with continuous mode uses default physics', () {
      const settings = ReaderSettings(
        mode: ReaderMode.continuous,
      );
      expect(settings.scrollSnap, isFalse);
      expect(settings.mode, ReaderMode.continuous);
    });
  });
}
