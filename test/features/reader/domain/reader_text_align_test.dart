import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderTextAlign', () {
    test('asInBook exists with correct display name', () {
      expect(ReaderTextAlign.asInBook, isNotNull);
      expect(ReaderTextAlign.asInBook.displayName, 'Как в книге');
    });

    test('all values have display names', () {
      for (final value in ReaderTextAlign.values) {
        expect(value.displayName, isNotEmpty);
      }
    });

    test('has exactly 5 values', () {
      expect(ReaderTextAlign.values.length, 5);
    });
  });

  group('ReaderSettings.textAlign', () {
    test('defaults to justify', () {
      const settings = ReaderSettings();
      expect(settings.textAlign, ReaderTextAlign.justify);
    });

    test('can be set to asInBook', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(textAlign: ReaderTextAlign.asInBook);
      expect(updated.textAlign, ReaderTextAlign.asInBook);
    });

    test('copyWith preserves textAlign when not specified', () {
      const settings = ReaderSettings(textAlign: ReaderTextAlign.asInBook);
      final updated = settings.copyWith(fontSize: 24.0);
      expect(updated.textAlign, ReaderTextAlign.asInBook);
    });
  });
}
