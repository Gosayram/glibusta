import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/services/cover_service.dart';

void main() {
  group('CoverService.getUrl', () {
    test('returns null for null coverPath', () {
      final service = CoverService(baseUrl: 'https://example.com');
      expect(service.getUrl(null, CoverSize.thumb), isNull);
    });

    test('returns null for empty coverPath', () {
      final service = CoverService(baseUrl: 'https://example.com');
      expect(service.getUrl('  ', CoverSize.thumb), isNull);
    });

    test('prepends baseUrl for relative paths', () {
      final service = CoverService(baseUrl: 'https://example.com');
      final url = service.getUrl('covers/book.jpg', CoverSize.thumb);
      expect(url, startsWith('https://example.com/covers/book'));
      expect(url, endsWith('.jpg'));
    });

    test('does not prepend baseUrl for http URLs', () {
      final service = CoverService(baseUrl: 'https://example.com');
      final url = service.getUrl(
        'https://cdn.example.com/cover.jpg',
        CoverSize.large,
      );
      expect(url, startsWith('https://cdn.example.com'));
      expect(url, isNot(contains('example.com/https')));
    });

    test('applies thumb suffix', () {
      final service = CoverService(baseUrl: 'https://example.com');
      final url = service.getUrl('cover.jpg', CoverSize.thumb);
      expect(url, contains('_t80x120'));
    });

    test('applies medium suffix', () {
      final service = CoverService(baseUrl: 'https://example.com');
      final url = service.getUrl('cover.jpg', CoverSize.medium);
      expect(url, contains('_t200x300'));
    });

    test('applies large suffix', () {
      final service = CoverService(baseUrl: 'https.example.com');
      final url = service.getUrl('cover.jpg', CoverSize.large);
      expect(url, contains('_t400x600'));
    });

    test('handles baseUrl with trailing slash', () {
      final service = CoverService(baseUrl: 'https://example.com/');
      final url = service.getUrl('cover.jpg', CoverSize.thumb);
      expect(url, startsWith('https://example.com/'));
    });

    test('no baseUrl uses path directly', () {
      final service = CoverService();
      final url = service.getUrl('https://cdn.test.com/c.jpg', CoverSize.thumb);
      expect(url, startsWith('https://cdn.test.com'));
    });

    test('suffix inserted before extension', () {
      final service = CoverService();
      final url = service.getUrl('https://test.com/cover.jpg', CoverSize.thumb);
      expect(url, contains('cover_t80x120.jpg'));
    });
  });

  group('CoverSize', () {
    test('has thumb, medium, large', () {
      expect(CoverSize.values.length, 3);
      expect(CoverSize.values, contains(CoverSize.thumb));
      expect(CoverSize.values, contains(CoverSize.medium));
      expect(CoverSize.values, contains(CoverSize.large));
    });
  });

  group('CoverService.instance', () {
    test('singleton returns same instance', () {
      expect(CoverService.instance, same(CoverService.instance));
    });
  });
}
