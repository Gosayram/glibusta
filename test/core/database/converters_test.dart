import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/converters.dart';

void main() {
  group('StringListConverter', () {
    const converter = StringListConverter();

    test('toSql encodes list to JSON', () {
      final result = converter.toSql(['a', 'b', 'c']);
      expect(result, '["a","b","c"]');
    });

    test('toSql encodes empty list', () {
      expect(converter.toSql([]), '[]');
    });

    test('toSql encodes list with special chars', () {
      final result = converter.toSql([r'hello "world"', 'line\nbreak']);
      expect(result, contains(r'"hello \"world\""'));
      expect(result, contains(r'line\nbreak'));
    });

    test('toSql encodes unicode strings', () {
      final result = converter.toSql(['Привет', 'Мир']);
      expect(result, contains('Привет'));
      expect(result, contains('Мир'));
    });

    test('fromSql decodes JSON to list', () {
      final result = converter.fromSql('["x","y"]');
      expect(result, ['x', 'y']);
    });

    test('fromSql returns empty list for empty string', () {
      expect(converter.fromSql(''), isEmpty);
    });

    test('fromSql decodes unicode', () {
      final json = converter.toSql(['Тест']);
      final result = converter.fromSql(json);
      expect(result, ['Тест']);
    });

    test('roundtrip preserves data', () {
      const original = ['epub', 'fb2', 'txt with spaces', 'книга'];
      final sql = converter.toSql(original);
      final restored = converter.fromSql(sql);
      expect(restored, original);
    });

    test('roundtrip with empty list', () {
      final sql = converter.toSql([]);
      final restored = converter.fromSql(sql);
      expect(restored, isEmpty);
    });

    test('fromSql handles single-element list', () {
      final result = converter.fromSql('["one"]');
      expect(result, ['one']);
    });
  });
}
