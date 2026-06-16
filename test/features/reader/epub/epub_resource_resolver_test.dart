import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/epub/epub_models.dart';
import 'package:glibusta/features/reader/epub/epub_resource_resolver.dart';

void main() {
  group('EpubResourceResolver', () {
    final resources = {
      'img1': const EpubResource(
        id: 'img1',
        href: 'images/photo.jpg',
        fullPath: 'OEBPS/images/photo.jpg',
        mediaType: 'image/jpeg',
        properties: {},
        type: EpubResourceType.image,
      ),
      'style': const EpubResource(
        id: 'style',
        href: 'styles/main.css',
        fullPath: 'OEBPS/styles/main.css',
        mediaType: 'text/css',
        properties: {},
        type: EpubResourceType.css,
      ),
    };

    final resolver = EpubResourceResolver(resources);

    test('resolves relative href', () {
      final result = resolver.resolveFromHref(
        chapterPath: 'OEBPS/chapters/ch1.xhtml',
        href: '../images/photo.jpg',
      );
      expect(result?.id, 'img1');
    });

    test('rejects absolute path', () {
      final result = resolver.resolveFromHref(
        chapterPath: 'OEBPS/chapters/ch1.xhtml',
        href: '/etc/passwd',
      );
      expect(result, isNull);
    });

    test('rejects path traversal with ..', () {
      final result = resolver.resolveFromHref(
        chapterPath: 'OEBPS/chapters/ch1.xhtml',
        href: '../../etc/passwd',
      );
      expect(result, isNull);
    });

    test('rejects empty href', () {
      final result = resolver.resolveFromHref(
        chapterPath: 'OEBPS/chapters/ch1.xhtml',
        href: '',
      );
      expect(result, isNull);
    });

    test('strips fragment from href', () {
      final result = resolver.resolveFromHref(
        chapterPath: 'OEBPS/chapters/ch1.xhtml',
        href: '../images/photo.jpg#section1',
      );
      expect(result?.id, 'img1');
    });
  });
}
