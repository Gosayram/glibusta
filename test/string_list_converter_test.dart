import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/converters.dart';

void main() {
  group('StringListConverter', () {
    const converter = StringListConverter();

    test('fromSql returns empty list for empty string', () {
      expect(converter.fromSql(''), isEmpty);
    });

    test('fromSql decodes JSON array of strings', () {
      final result = converter.fromSql('["one","two","three"]');
      expect(result, ['one', 'two', 'three']);
    });

    test('fromSql handles single element', () {
      final result = converter.fromSql('["hello"]');
      expect(result, ['hello']);
    });

    test('fromSql handles empty JSON array', () {
      final result = converter.fromSql('[]');
      expect(result, isEmpty);
    });

    test('toSql encodes list to JSON array', () {
      final result = converter.toSql(['one', 'two']);
      expect(result, '["one","two"]');
    });

    test('toSql handles empty list', () {
      final result = converter.toSql([]);
      expect(result, '[]');
    });

    test('toSql handles single element', () {
      final result = converter.toSql(['hello']);
      expect(result, '["hello"]');
    });

    test('roundtrip preserves data', () {
      const original = ['alpha', 'beta', 'gamma'];
      final encoded = converter.toSql(original);
      final decoded = converter.fromSql(encoded);
      expect(decoded, original);
    });

    test('roundtrip with unicode characters', () {
      const original = ['Привет', 'Мир', 'Тест'];
      final encoded = converter.toSql(original);
      final decoded = converter.fromSql(encoded);
      expect(decoded, original);
    });

    test('roundtrip with special characters', () {
      const original = ['line1\nline2', 'tab\there', 'quote"here'];
      final encoded = converter.toSql(original);
      final decoded = converter.fromSql(encoded);
      expect(decoded, original);
    });
  });
}
