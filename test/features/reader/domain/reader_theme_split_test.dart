import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  group('ReaderSettings.uiTheme', () {
    test('defaults to null', () {
      const settings = ReaderSettings();
      expect(settings.uiTheme, isNull);
    });

    test('effectiveUiTheme falls back to content theme when uiTheme is null', () {
      const settings = ReaderSettings(theme: ReaderTheme.sepia);
      expect(settings.effectiveUiTheme, ReaderTheme.sepia);
    });

    test('effectiveUiTheme uses uiTheme when set', () {
      const settings = ReaderSettings(
        theme: ReaderTheme.sepia,
        uiTheme: ReaderTheme.dark,
      );
      expect(settings.effectiveUiTheme, ReaderTheme.dark);
    });

    test('copyWith sets uiTheme', () {
      const settings = ReaderSettings();
      final updated = settings.copyWith(uiTheme: ReaderTheme.oled);
      expect(updated.uiTheme, ReaderTheme.oled);
    });

    test('copyWith resets uiTheme to null', () {
      const settings = ReaderSettings(uiTheme: ReaderTheme.dark);
      final updated = settings.copyWith(uiTheme: null);
      expect(updated.uiTheme, isNull);
    });

    test('copyWith preserves uiTheme when not specified', () {
      const settings = ReaderSettings(uiTheme: ReaderTheme.bedtime);
      final updated = settings.copyWith(fontSize: 24.0);
      expect(updated.uiTheme, ReaderTheme.bedtime);
      expect(updated.fontSize, 24.0);
    });

    test('theme and uiTheme can differ independently', () {
      const settings = ReaderSettings(
        theme: ReaderTheme.light,
        uiTheme: ReaderTheme.dark,
      );
      expect(settings.theme, ReaderTheme.light);
      expect(settings.uiTheme, ReaderTheme.dark);
      expect(settings.effectiveUiTheme, ReaderTheme.dark);
    });
  });
}
