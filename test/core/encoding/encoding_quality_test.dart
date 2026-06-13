import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/encoding/encoding_quality.dart';

void main() {
  group('encodingQualityScore', () {
    test('empty text returns 0', () {
      expect(encodingQualityScore(''), 0);
    });

    test('clean Russian text scores high', () {
      const text =
          'Онегин жил на阆 Пукшин Пушкин как это книга глава в не на';
      final score = encodingQualityScore(text);
      expect(score, greaterThan(0.7));
    });

    test('mojibake text scores low', () {
      const text = 'ÐÑÐÑÑÐÑÑÐÑÑÐÑÑÐÑÑÐÑÑÐÑÑÐÑÑÐÑÑ';
      final score = encodingQualityScore(text);
      expect(score, lessThan(0.5));
    });

    test('text with replacement characters scores low', () {
      final text = '\uFFFD\uFFFD\uFFFDnormal text here';
      final score = encodingQualityScore(text);
      expect(score, lessThan(0.8));
    });

    test('text with control characters scores lower', () {
      final text = String.fromCharCodes([0x01, 0x02, 0x03, 0x41, 0x42]);
      final score = encodingQualityScore(text);
      expect(score, lessThan(0.9));
    });

    test('common Russian words boost score', () {
      const text =
          'Это книга не как он она это его в на что глава книга';
      final score = encodingQualityScore(text);
      expect(score, greaterThan(0.8));
    });

    test('score is clamped between 0 and 1', () {
      final score = encodingQualityScore('Привет мир');
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('text with very low letter density penalized', () {
      const text = '123456789012345678901234567890';
      final score = encodingQualityScore(text);
      expect(score, lessThan(0.8));
    });

    test('long text sample truncated to 20000 chars', () {
      final text = 'А' * 30000;
      final score = encodingQualityScore(text);
      expect(score, greaterThan(0.0));
    });
  });
}
