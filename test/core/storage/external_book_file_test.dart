import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/storage/external_book_file.dart';

void main() {
  group('ExternalBookFile', () {
    test('stores all fields', () {
      const file = ExternalBookFile(
        uri: 'content://com.android.providers.downloads/1',
        name: 'book.fb2',
        size: 1024000,
        extension: 'fb2',
      );
      expect(file.uri, 'content://com.android.providers.downloads/1');
      expect(file.name, 'book.fb2');
      expect(file.size, 1024000);
      expect(file.extension, 'fb2');
    });

    test('extension can be uppercase', () {
      const file = ExternalBookFile(
        uri: 'uri',
        name: 'book.EPUB',
        size: 500,
        extension: 'EPUB',
      );
      expect(file.extension, 'EPUB');
    });

    test('size can be 0', () {
      const file = ExternalBookFile(
        uri: 'uri',
        name: 'empty.txt',
        size: 0,
        extension: 'txt',
      );
      expect(file.size, 0);
    });

    test('name can contain spaces', () {
      const file = ExternalBookFile(
        uri: 'uri',
        name: 'My Book.fb2',
        size: 100,
        extension: 'fb2',
      );
      expect(file.name, 'My Book.fb2');
    });

    test('stores optional platform metadata', () {
      const file = ExternalBookFile(
        uri: 'uri',
        name: 'book.epub',
        size: 100,
        extension: 'epub',
        mimeType: 'application/epub+zip',
        lastModified: 123456789,
      );

      expect(file.mimeType, 'application/epub+zip');
      expect(file.lastModified, 123456789);
    });
  });
}
