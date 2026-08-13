import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  tearDown(() => clearCssCache());

  group('_parseCustomCss caching', () {
    test('returns same cached instance for identical input', () {
      const css = 'p { font-size: 18; line-height: 1.6; }';
      final first = parseCustomCssForTest(css);
      final second = parseCustomCssForTest(css);
      expect(identical(first, second), isTrue);
      expect(second['font-size'], 18.0);
      expect(second['line-height'], 1.6);
    });

    test('different inputs produce different results', () {
      const css1 = 'p { font-size: 18; }';
      const css2 = 'p { font-size: 22; }';
      final r1 = parseCustomCssForTest(css1);
      final r2 = parseCustomCssForTest(css2);
      expect(r1['font-size'], 18.0);
      expect(r2['font-size'], 22.0);
      expect(identical(r1, r2), isFalse);
    });

    test('empty CSS returns empty map', () {
      final r = parseCustomCssForTest('');
      expect(r, isEmpty);
    });

    test('clearCssCache invalidates cache', () {
      const css = 'p { font-size: 18; }';
      final first = parseCustomCssForTest(css);
      clearCssCache();
      final second = parseCustomCssForTest(css);
      expect(first['font-size'], second['font-size']);
      expect(identical(first, second), isFalse);
    });
  });
}
