import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderSettings.eink', () {
    test('defaults to false', () {
      const settings = ReaderSettings();
      expect(settings.eink, isFalse);
    });

    test('copyWith sets eink', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(eink: true);
      expect(updated.eink, isTrue);
    });

    test('copyWith preserves eink when not specified', () {
      const settings = ReaderSettings(eink: true);
      final updated = settings.copyWith(fontSize: 24.0);
      expect(updated.eink, isTrue);
    });

    test('copyWith resets eink to false', () {
      const settings = ReaderSettings(eink: true);
      final updated = settings.copyWith(eink: false);
      expect(updated.eink, isFalse);
    });

    test('eink true disables autoTheme', () {
      const settings = ReaderSettings(eink: true);
      expect(settings.autoThemeMode, AutoThemeMode.off);
    });
  });
}
