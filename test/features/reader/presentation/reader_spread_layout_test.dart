import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_spread_layout.dart';

void main() {
  group('shouldUseTwoPageReaderLayout', () {
    test('uses the stored spread preference on a comfortably wide reader surface', () {
      expect(
        shouldUseTwoPageReaderLayout(
          preferenceEnabled: true,
          deviceSupportsTwoPageMode: true,
          contentWidth: 820,
          scaledFontSize: 18,
        ),
        isTrue,
      );
    });

    test('keeps one page when either the preference or device capability is absent', () {
      expect(
        shouldUseTwoPageReaderLayout(
          preferenceEnabled: false,
          deviceSupportsTwoPageMode: true,
          contentWidth: 1200,
          scaledFontSize: 18,
        ),
        isFalse,
      );
      expect(
        shouldUseTwoPageReaderLayout(
          preferenceEnabled: true,
          deviceSupportsTwoPageMode: false,
          contentWidth: 1200,
          scaledFontSize: 18,
        ),
        isFalse,
      );
    });

    test('falls back to one page when large text would make spread columns unreadable', () {
      expect(
        shouldUseTwoPageReaderLayout(
          preferenceEnabled: true,
          deviceSupportsTwoPageMode: true,
          contentWidth: 820,
          scaledFontSize: 24,
        ),
        isFalse,
      );
    });

    test('re-enables the preserved preference after width becomes sufficient', () {
      expect(
        shouldUseTwoPageReaderLayout(
          preferenceEnabled: true,
          deviceSupportsTwoPageMode: true,
          contentWidth: 1000,
          scaledFontSize: 24,
        ),
        isTrue,
      );
    });
  });
}
