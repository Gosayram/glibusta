import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/formats/format_capability.dart';

void main() {
  group('BookFormatCapability extension', () {
    test('epub is readable', () {
      expect(BookFormat.epub.capability, FormatCapability.readable);
      expect(BookFormat.epub.canReadInApp, isTrue);
      expect(BookFormat.epub.canImport, isTrue);
      expect(BookFormat.epub.isDocumentOnly, isFalse);
      expect(BookFormat.epub.hasReaderRoute, isTrue);
    });

    test('fb2 is readable', () {
      expect(BookFormat.fb2.capability, FormatCapability.readable);
      expect(BookFormat.fb2.canReadInApp, isTrue);
    });

    test('txt is readable', () {
      expect(BookFormat.txt.capability, FormatCapability.readable);
      expect(BookFormat.txt.canReadInApp, isTrue);
    });

    test('rtf is readable', () {
      expect(BookFormat.rtf.capability, FormatCapability.readable);
      expect(BookFormat.rtf.canReadInApp, isTrue);
    });

    test('mobi is readable', () {
      expect(BookFormat.mobi.capability, FormatCapability.readable);
      expect(BookFormat.mobi.canReadInApp, isTrue);
    });

    test('azw3 is partial', () {
      expect(BookFormat.azw3.capability, FormatCapability.partial);
      expect(BookFormat.azw3.canReadInApp, isTrue);
      expect(BookFormat.azw3.canImport, isTrue);
      expect(BookFormat.azw3.isDocumentOnly, isFalse);
    });

    test('prc is legacy', () {
      expect(BookFormat.prc.capability, FormatCapability.legacy);
      expect(BookFormat.prc.canReadInApp, isTrue);
      expect(BookFormat.prc.canImport, isTrue);
    });

    test('pdf is documentOnly', () {
      expect(BookFormat.pdf.capability, FormatCapability.documentOnly);
      expect(BookFormat.pdf.canReadInApp, isFalse);
      expect(BookFormat.pdf.canImport, isTrue);
      expect(BookFormat.pdf.isDocumentOnly, isTrue);
      expect(BookFormat.pdf.hasReaderRoute, isTrue);
    });

    test('djvu is documentOnly', () {
      expect(BookFormat.djvu.capability, FormatCapability.documentOnly);
      expect(BookFormat.djvu.canReadInApp, isFalse);
      expect(BookFormat.djvu.isDocumentOnly, isTrue);
      expect(BookFormat.djvu.hasReaderRoute, isTrue);
    });

    test('cbr is readable through the native RAR decoder', () {
      expect(BookFormat.cbr.capability, FormatCapability.readable);
      expect(BookFormat.cbr.canReadInApp, isTrue);
      expect(BookFormat.cbr.canImport, isTrue);
    });

    test('unknown is unsupported', () {
      expect(BookFormat.unknown.capability, FormatCapability.unsupported);
      expect(BookFormat.unknown.canReadInApp, isFalse);
      expect(BookFormat.unknown.canImport, isFalse);
      expect(BookFormat.unknown.isDocumentOnly, isFalse);
      expect(BookFormat.unknown.hasReaderRoute, isFalse);
    });
  });

  group('FormatCapability extensions', () {
    test('readable canReadInApp', () {
      expect(FormatCapability.readable.canReadInApp, isTrue);
      expect(FormatCapability.readable.canImport, isTrue);
      expect(FormatCapability.readable.isDocumentOnly, isFalse);
      expect(FormatCapability.readable.hasReaderRoute, isTrue);
    });

    test('partial canReadInApp', () {
      expect(FormatCapability.partial.canReadInApp, isTrue);
      expect(FormatCapability.partial.canImport, isTrue);
    });

    test('legacy canReadInApp', () {
      expect(FormatCapability.legacy.canReadInApp, isTrue);
    });

    test('documentOnly', () {
      expect(FormatCapability.documentOnly.canReadInApp, isFalse);
      expect(FormatCapability.documentOnly.canImport, isTrue);
      expect(FormatCapability.documentOnly.isDocumentOnly, isTrue);
      expect(FormatCapability.documentOnly.hasReaderRoute, isTrue);
    });

    test('unsupported', () {
      expect(FormatCapability.unsupported.canReadInApp, isFalse);
      expect(FormatCapability.unsupported.canImport, isFalse);
      expect(FormatCapability.unsupported.isDocumentOnly, isFalse);
      expect(FormatCapability.unsupported.hasReaderRoute, isFalse);
    });
  });

  group('warningLabel', () {
    test('null for readable formats', () {
      expect(BookFormat.epub.warningLabel(), isNull);
      expect(BookFormat.fb2.warningLabel(), isNull);
      expect(BookFormat.txt.warningLabel(), isNull);
      expect(BookFormat.rtf.warningLabel(), isNull);
      expect(BookFormat.mobi.warningLabel(), isNull);
    });

    test('non-null for documentOnly', () {
      expect(BookFormat.pdf.warningLabel(), isNotNull);
      expect(BookFormat.djvu.warningLabel(), isNotNull);
    });

    test('non-null for partial', () {
      expect(BookFormat.azw3.warningLabel(), isNotNull);
      expect(BookFormat.azw3.warningLabel(), contains('MOBI'));
    });

    test('non-null for legacy', () {
      expect(BookFormat.prc.warningLabel(), isNotNull);
      expect(BookFormat.prc.warningLabel(), contains('legacy'));
    });

    test('non-null for unsupported', () {
      expect(BookFormat.unknown.warningLabel(), isNotNull);
      expect(BookFormat.unknown.warningLabel(), contains('не поддерживается'));
    });
  });

  group('all formats covered', () {
    test('every BookFormat has a defined capability', () {
      for (final format in BookFormat.values) {
        expect(
          () => format.capability,
          returnsNormally,
          reason: 'format ${format.name} should have a capability',
        );
      }
    });
  });
}
