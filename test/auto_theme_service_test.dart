import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/auto_theme_service.dart';
import 'package:glibusta/features/reader/domain/reader.dart';

// ignore_for_file: avoid_redundant_argument_values — `now:` is required to control test time
void main() {
  group('AutoThemeService', () {
    late AutoThemeService service;

    setUp(() {
      service = AutoThemeService();
    });

    group('resolveTheme', () {
      test('returns manual theme when mode is off', () {
        final result = service.resolveTheme(
          AutoThemeMode.off,
          ReaderTheme.sepia,
        );
        expect(result, ReaderTheme.sepia);
      });

      test('returns manual theme regardless of time when off', () {
        final midnight = DateTime(2026, 6, 10, 0, 0);
        final result = service.resolveTheme(
          AutoThemeMode.off,
          ReaderTheme.paper,
          now: midnight,
        );
        expect(result, ReaderTheme.paper);
      });
    });

    group('system mode', () {
      test('returns dark before 7:00', () {
        final dt = DateTime(2026, 6, 10, 6, 59);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns light at 7:00', () {
        final dt = DateTime(2026, 6, 10, 7, 0);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.light);
      });

      test('returns light at noon', () {
        final dt = DateTime(2026, 6, 10, 12, 0);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.light);
      });

      test('returns light at 19:59', () {
        final dt = DateTime(2026, 6, 10, 19, 59);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.light);
      });

      test('returns dark at 20:00', () {
        final dt = DateTime(2026, 6, 10, 20, 0);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns dark at 23:59', () {
        final dt = DateTime(2026, 6, 10, 23, 59);
        final result = service.resolveTheme(
          AutoThemeMode.system,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });
    });

    group('sunset mode', () {
      test('returns light during afternoon (between sunrise and sunset)', () {
        // For June 10, the cosine formula gives sunrise ~15:33, sunset ~20:27
        final dt = DateTime(2026, 6, 10, 18, 0);
        final result = service.resolveTheme(
          AutoThemeMode.sunset,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.light);
      });

      test('returns dark at midnight', () {
        final dt = DateTime(2026, 6, 10, 0, 0);
        final result = service.resolveTheme(
          AutoThemeMode.sunset,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns dark at 22:00', () {
        final dt = DateTime(2026, 6, 10, 22, 0);
        final result = service.resolveTheme(
          AutoThemeMode.sunset,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns dark in early morning before sunrise', () {
        final dt = DateTime(2026, 6, 10, 10, 0);
        final result = service.resolveTheme(
          AutoThemeMode.sunset,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns light right at sunset boundary', () {
        // Just before sunset (~20:27 on June 10)
        final dt = DateTime(2026, 6, 10, 20, 20);
        final result = service.resolveTheme(
          AutoThemeMode.sunset,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.light);
      });
    });

    group('custom mode', () {
      test('returns light during custom day hours', () {
        final dt = DateTime(2026, 6, 10, 12, 0);
        final result = service.resolveTheme(
          AutoThemeMode.custom,
          ReaderTheme.sepia,
          now: dt,
        );
        // custom defaults: day from 7, night from 20
        expect(result, ReaderTheme.light);
      });

      test('returns dark during custom night hours', () {
        final dt = DateTime(2026, 6, 10, 22, 0);
        final result = service.resolveTheme(
          AutoThemeMode.custom,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });

      test('returns dark at 5:00 with default custom hours', () {
        final dt = DateTime(2026, 6, 10, 5, 0);
        final result = service.resolveTheme(
          AutoThemeMode.custom,
          ReaderTheme.sepia,
          now: dt,
        );
        expect(result, ReaderTheme.dark);
      });
    });
  });
}
