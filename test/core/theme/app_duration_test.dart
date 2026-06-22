import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/theme/app_duration.dart';

void main() {
  group('AppDuration', () {
    test('fast transitions', () {
      expect(AppDuration.fast, const Duration(milliseconds: 150));
      expect(AppDuration.normal, const Duration(milliseconds: 300));
      expect(AppDuration.slow, const Duration(milliseconds: 500));
    });

    test('timer durations', () {
      expect(AppDuration.readerProgressSave, const Duration(seconds: 5));
    });

    test('network timeouts', () {
      expect(AppDuration.httpConnect, const Duration(seconds: 10));
      expect(AppDuration.httpReceive, const Duration(seconds: 30));
    });

    test('reader theme transition', () {
      expect(AppDuration.readerThemeTransition, const Duration(milliseconds: 250));
    });

    test('auto theme check', () {
      expect(AppDuration.autoThemeCheck, const Duration(minutes: 1));
    });

    test('slow is slowest transition', () {
      expect(AppDuration.slow > AppDuration.normal, isTrue);
    });
  });
}
