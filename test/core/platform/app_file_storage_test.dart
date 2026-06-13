import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  group('sanitizeId', () {
    test('replaces slashes', () {
      expect(sanitizeId('a/b'), 'a_b');
      expect(sanitizeId('path/to/file'), 'path_to_file');
    });

    test('replaces backslashes', () {
      expect(sanitizeId(r'a\b'), 'a_b');
    });

    test('replaces colons', () {
      expect(sanitizeId(r'C:\path'), 'C__path');
    });

    test('replaces asterisks', () {
      expect(sanitizeId('file*name'), 'file_name');
    });

    test('replaces question marks', () {
      expect(sanitizeId('file?'), 'file_');
    });

    test('replaces double quotes', () {
      expect(sanitizeId(r'say "hi"'), 'say _hi_');
    });

    test('replaces angle brackets', () {
      expect(sanitizeId('<test>'), '_test_');
    });

    test('replaces pipe', () {
      expect(sanitizeId('a|b'), 'a_b');
    });

    test('replaces dots', () {
      expect(sanitizeId('file.name'), 'file_name');
    });

    test('leaves normal id unchanged', () {
      expect(sanitizeId('book123'), 'book123');
      expect(sanitizeId('abc-def_123'), 'abc-def_123');
    });

    test('handles empty string', () {
      expect(sanitizeId(''), '');
    });

    test('handles id with multiple special chars', () {
      final result = sanitizeId('a/b:c*d?"e<f>g|h');
      expect(result, contains('a_b'));
      expect(result, isNot(contains('/')));
      expect(result, isNot(contains(':')));
      expect(result, isNot(contains('*')));
      expect(result, isNot(contains('?')));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
      expect(result, isNot(contains('|')));
    });
  });

  group('BookFormat extension helpers', () {
    test('all format names are lowercase', () {
      for (final f in BookFormat.values) {
        expect(f.name, f.name.toLowerCase());
      }
    });
  });
}
