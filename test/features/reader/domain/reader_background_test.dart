import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('BackgroundStyle', () {
    test('has five values', () {
      expect(BackgroundStyle.values.length, 5);
    });

    test('default value is solid', () {
      const settings = ReaderSettings();
      expect(settings.backgroundStyle, BackgroundStyle.solid);
    });

    test('copyWith sets backgroundStyle', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(backgroundStyle: BackgroundStyle.parchment);
      expect(updated.backgroundStyle, BackgroundStyle.parchment);
    });

    test('copyWith preserves other fields', () {
      const settings = ReaderSettings(fontSize: 22);
      final updated = settings.copyWith(backgroundStyle: BackgroundStyle.darkPaper);
      expect(updated.backgroundStyle, BackgroundStyle.darkPaper);
      expect(updated.fontSize, 22);
    });

    test('displayName is non-empty for all values', () {
      for (final style in BackgroundStyle.values) {
        expect(style.displayName, isNotEmpty);
      }
    });
  });
}
