import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/auto_theme_service.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

void main() {
  late AutoThemeService service;

  setUp(() {
    service = AutoThemeService();
  });

  group('resolveTheme', () {
    test('off mode returns manual theme', () {
      final result = service.resolveTheme(
        AutoThemeMode.off,
        ReaderTheme.sepia,
        now: DateTime(2026, 6, 13, 12),
      );
      expect(result, ReaderTheme.sepia);
    });

    test('system mode: night returns dark', () {
      final result = service.resolveTheme(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 23),
      );
      expect(result, ReaderTheme.dark);
    });

    test('system mode: day returns light', () {
      final result = service.resolveTheme(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 12),
      );
      expect(result, ReaderTheme.light);
    });

    test('system mode: early morning is night', () {
      final result = service.resolveTheme(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 5),
      );
      expect(result, ReaderTheme.dark);
    });

    test('system mode: 7am is day', () {
      final result = service.resolveTheme(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 7),
      );
      expect(result, ReaderTheme.light);
    });

    test('system mode: 20:00 is night', () {
      final result = service.resolveTheme(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 20),
      );
      expect(result, ReaderTheme.dark);
    });

    test('sunset mode: day before sunset', () {
      final result = service.resolveTheme(
        AutoThemeMode.sunset,
        ReaderTheme.light,
        now: DateTime(2026, 12, 13, 10),
      );
      expect(result, ReaderTheme.light);
    });

    test('custom mode: night during custom hours', () {
      final result = service.resolveTheme(
        AutoThemeMode.custom,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 22),
      );
      expect(result, ReaderTheme.dark);
    });

    test('custom mode: day during custom hours', () {
      final result = service.resolveTheme(
        AutoThemeMode.custom,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 12),
      );
      expect(result, ReaderTheme.light);
    });
  });

  group('resolveWarmth', () {
    test('off returns 0', () {
      final warmth = service.resolveWarmth(
        AutoThemeMode.off,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 12),
      );
      expect(warmth, 0.0);
    });

    test('bedtime returns 0.6', () {
      final warmth = service.resolveWarmth(
        AutoThemeMode.system,
        ReaderTheme.bedtime,
        now: DateTime(2026, 6, 13, 23),
      );
      expect(warmth, 0.6);
    });

    test('dark returns 0.15', () {
      final warmth = service.resolveWarmth(
        AutoThemeMode.system,
        ReaderTheme.dark,
        now: DateTime(2026, 6, 13, 23),
      );
      expect(warmth, 0.15);
    });

    test('light returns 0', () {
      final warmth = service.resolveWarmth(
        AutoThemeMode.system,
        ReaderTheme.light,
        now: DateTime(2026, 6, 13, 12),
      );
      expect(warmth, 0.0);
    });
  });
}
