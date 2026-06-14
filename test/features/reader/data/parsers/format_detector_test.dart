import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';

void main() {
  group('detectBookFormat', () {
    test('detects epub', () {
      expect(detectBookFormat('book.epub'), BookFormat.epub);
      expect(detectBookFormat('/path/to/BOOK.EPUB'), BookFormat.epub);
    });

    test('detects fb2', () {
      expect(detectBookFormat('book.fb2'), BookFormat.fb2);
      expect(detectBookFormat('/path/book.FB2'), BookFormat.fb2);
    });

    test('detects pdf', () {
      expect(detectBookFormat('document.pdf'), BookFormat.pdf);
      expect(detectBookFormat('FILE.PDF'), BookFormat.pdf);
    });

    test('detects txt', () {
      expect(detectBookFormat('text.txt'), BookFormat.txt);
      expect(detectBookFormat('readme.TXT'), BookFormat.txt);
    });

    test('detects mobi', () {
      expect(detectBookFormat('book.mobi'), BookFormat.mobi);
      expect(detectBookFormat('BOOK.MOBI'), BookFormat.mobi);
    });

    test('detects rtf', () {
      expect(detectBookFormat('book.rtf'), BookFormat.rtf);
      expect(detectBookFormat('BOOK.RTF'), BookFormat.rtf);
    });

    test('detects djvu', () {
      expect(detectBookFormat('book.djvu'), BookFormat.djvu);
      expect(detectBookFormat('book.djv'), BookFormat.djvu);
      expect(detectBookFormat('BOOK.DJVU'), BookFormat.djvu);
    });

    test('zip is unknown (cannot determine content without inspection)', () {
      expect(detectBookFormat('book.zip'), BookFormat.unknown);
    });

    test('unknown format for unsupported extension', () {
      expect(detectBookFormat('image.jpg'), BookFormat.unknown);
      expect(detectBookFormat('file.docx'), BookFormat.unknown);
      expect(detectBookFormat('archive.rar'), BookFormat.unknown);
      expect(detectBookFormat('book.epub2'), BookFormat.unknown);
    });

    test('handles paths with multiple dots', () {
      expect(detectBookFormat('my.book.name.epub'), BookFormat.epub);
      expect(detectBookFormat('file.name.fb2.zip'), BookFormat.unknown);
    });

    test('handles no extension', () {
      expect(detectBookFormat('noext'), BookFormat.unknown);
    });

    test('handles empty string', () {
      expect(detectBookFormat(''), BookFormat.unknown);
    });

    test('handles relative paths', () {
      expect(detectBookFormat('./books/novel.epub'), BookFormat.epub);
      expect(detectBookFormat('../downloads/read.txt'), BookFormat.txt);
    });
  });
}
