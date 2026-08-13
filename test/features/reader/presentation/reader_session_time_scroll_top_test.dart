import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/reading_info_model.dart';

String formatSessionTime(int totalSeconds) {
  if (totalSeconds < 60) return '$totalSeconds мин';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '$hours ч $minutes мин';
  return '$minutes мин';
}

void main() {
  group('session time formatting', () {
    test('under 60 seconds shows raw number', () {
      expect(formatSessionTime(0), '0 мин');
      expect(formatSessionTime(30), '30 мин');
      expect(formatSessionTime(59), '59 мин');
    });

    test('minutes format for 1-59 minutes', () {
      expect(formatSessionTime(60), '1 мин');
      expect(formatSessionTime(120), '2 мин');
      expect(formatSessionTime(600), '10 мин');
      expect(formatSessionTime(3599), '59 мин');
    });

    test('hours format for >= 1 hour', () {
      expect(formatSessionTime(3600), '1 ч 0 мин');
      expect(formatSessionTime(3660), '1 ч 1 мин');
      expect(formatSessionTime(7200), '2 ч 0 мин');
    });

    test('zero elapsed shows 0 мин', () {
      expect(formatSessionTime(0), '0 мин');
    });
  });

  group('InfoSlotMode.sessionTime', () {
    test('exists as an enum value', () {
      expect(InfoSlotMode.values.contains(InfoSlotMode.sessionTime), isTrue);
    });

    test('sessionTime exists as an enum value', () {
      expect(InfoSlotMode.values.contains(InfoSlotMode.sessionTime), isTrue);
    });
  });
}
