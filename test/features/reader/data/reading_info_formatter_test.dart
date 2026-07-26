import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_formatter.dart';

void main() {
  group('formatReadingTimeEstimate', () {
    test('uses a neutral placeholder when no reliable estimate exists', () {
      expect(formatReadingTimeEstimate(0), '—');
    });

    test('formats minutes and hours compactly', () {
      expect(formatReadingTimeEstimate(42), '~42 мин');
      expect(formatReadingTimeEstimate(60), '~1 ч');
      expect(formatReadingTimeEstimate(95), '~1 ч 35 мин');
    });
  });

  test('current chapter estimate uses the remaining chapter average', () {
    expect(
      formatCurrentChapterTimeEstimate(bookMinutesLeft: 95, chaptersRemaining: 3),
      '~32 мин',
    );
    expect(
      formatCurrentChapterTimeEstimate(bookMinutesLeft: 0, chaptersRemaining: 3),
      '—',
    );
  });
}
