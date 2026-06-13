import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_duration.dart';

void main() {
  group('AppDuration', () {
    test('fast transitions', () {
      expect(AppDuration.instant, const Duration(milliseconds: 50));
      expect(AppDuration.fast, const Duration(milliseconds: 150));
      expect(AppDuration.normal, const Duration(milliseconds: 300));
      expect(AppDuration.slow, const Duration(milliseconds: 500));
    });

    test('snackbar durations', () {
      expect(AppDuration.snackbarShort, const Duration(seconds: 2));
      expect(AppDuration.snackbarNormal, const Duration(seconds: 3));
      expect(AppDuration.snackbarLong, const Duration(seconds: 4));
    });

    test('timer durations', () {
      expect(AppDuration.readerHideDelay, const Duration(seconds: 3));
      expect(AppDuration.readerProgressSave, const Duration(seconds: 5));
    });

    test('network timeouts', () {
      expect(AppDuration.httpConnect, const Duration(seconds: 10));
      expect(AppDuration.httpReceive, const Duration(seconds: 30));
      expect(AppDuration.httpRequest, const Duration(seconds: 30));
    });

    test('reader theme transition', () {
      expect(AppDuration.readerThemeTransition, const Duration(milliseconds: 250));
    });

    test('auto theme check', () {
      expect(AppDuration.autoThemeCheck, const Duration(minutes: 1));
    });

    test('instant is fastest', () {
      expect(AppDuration.instant < AppDuration.fast, isTrue);
    });

    test('slow is slowest transition', () {
      expect(AppDuration.slow > AppDuration.normal, isTrue);
    });
  });
}
