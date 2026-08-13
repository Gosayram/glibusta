import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderSettings.noteFontSize', () {
    test('defaults to null', () {
      const settings = ReaderSettings();
      expect(settings.noteFontSize, isNull);
    });

    test('copyWith sets noteFontSize', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(noteFontSize: 14.0);
      expect(updated.noteFontSize, 14.0);
    });

    test('copyWith resets noteFontSize to null', () {
      const settings = ReaderSettings(noteFontSize: 14.0);
      final updated = settings.copyWith(noteFontSize: null);
      expect(updated.noteFontSize, isNull);
    });

    test('copyWith preserves noteFontSize when not specified', () {
      const settings = ReaderSettings(noteFontSize: 14.0);
      final updated = settings.copyWith(fontSize: 24.0);
      expect(updated.noteFontSize, 14.0);
      expect(updated.fontSize, 24.0);
    });
  });
}
