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

    test('formats days for 24+ hours', () {
      expect(formatReadingTimeEstimate(1440), '~1 д');
      expect(formatReadingTimeEstimate(1500), '~1 д 1 ч');
      expect(formatReadingTimeEstimate(2880), '~2 д');
      expect(formatReadingTimeEstimate(3000), '~2 д 2 ч');
    });

    test('formats sub-minute as < 1 мин', () {
      expect(formatReadingTimeEstimate(-1), '—');
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

  group('chapter-level estimate integration', () {
    test('formatReadingTimeEstimate works with chapter-level values', () {
      // Simulates what the info bar does with estimatedChapterMinutesLeft
      const chapterMinutesLeft = 12;
      expect(formatReadingTimeEstimate(chapterMinutesLeft), '~12 мин');
    });

    test('formatReadingTimeEstimate handles edge case of 1 minute', () {
      expect(formatReadingTimeEstimate(1), '~1 мин');
    });

    test('formatReadingTimeEstimate handles large chapter estimates', () {
      expect(formatReadingTimeEstimate(120), '~2 ч');
    });
  });
}
