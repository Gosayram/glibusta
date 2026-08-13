import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cover URL prefix logic', () {
    const base = 'https://example.test';

    String resolveCoverUrl(String? coverUrl, String base) {
      if (coverUrl == null || coverUrl.isEmpty) return '';
      if (coverUrl.startsWith('http')) return coverUrl;
      return '$base$coverUrl';
    }

    test('relative URL gets prefixed', () {
      expect(resolveCoverUrl('/covers/123.jpg', base), '$base/covers/123.jpg');
    });

    test('absolute https URL is not double-prefixed', () {
      expect(
        resolveCoverUrl('https://cdn.example.com/cover.jpg', base),
        'https://cdn.example.com/cover.jpg',
      );
    });

    test('null returns empty', () {
      expect(resolveCoverUrl(null, base), '');
    });

    test('empty returns empty', () {
      expect(resolveCoverUrl('', base), '');
    });
  });
}
