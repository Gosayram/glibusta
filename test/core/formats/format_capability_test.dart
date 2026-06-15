import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/formats/format_capability.dart';

void main() {
  const service = FormatCapabilityService();

  group('FormatCapabilityService', () {
    test('epub is readable', () {
      expect(service.capabilityOf(BookFormat.epub), FormatCapability.readable);
      expect(service.canReadInApp(BookFormat.epub), isTrue);
      expect(service.canImport(BookFormat.epub), isTrue);
      expect(service.isDocumentOnly(BookFormat.epub), isFalse);
      expect(service.hasReaderRoute(BookFormat.epub), isTrue);
    });

    test('fb2 is readable', () {
      expect(service.capabilityOf(BookFormat.fb2), FormatCapability.readable);
      expect(service.canReadInApp(BookFormat.fb2), isTrue);
    });

    test('txt is readable', () {
      expect(service.capabilityOf(BookFormat.txt), FormatCapability.readable);
      expect(service.canReadInApp(BookFormat.txt), isTrue);
    });

    test('rtf is readable', () {
      expect(service.capabilityOf(BookFormat.rtf), FormatCapability.readable);
      expect(service.canReadInApp(BookFormat.rtf), isTrue);
    });

    test('mobi is readable', () {
      expect(service.capabilityOf(BookFormat.mobi), FormatCapability.readable);
      expect(service.canReadInApp(BookFormat.mobi), isTrue);
    });

    test('azw3 is partial', () {
      expect(service.capabilityOf(BookFormat.azw3), FormatCapability.partial);
      expect(service.canReadInApp(BookFormat.azw3), isTrue);
      expect(service.canImport(BookFormat.azw3), isTrue);
      expect(service.isDocumentOnly(BookFormat.azw3), isFalse);
    });

    test('prc is legacy', () {
      expect(service.capabilityOf(BookFormat.prc), FormatCapability.legacy);
      expect(service.canReadInApp(BookFormat.prc), isTrue);
      expect(service.canImport(BookFormat.prc), isTrue);
    });

    test('pdf is documentOnly', () {
      expect(service.capabilityOf(BookFormat.pdf), FormatCapability.documentOnly);
      expect(service.canReadInApp(BookFormat.pdf), isFalse);
      expect(service.canImport(BookFormat.pdf), isTrue);
      expect(service.isDocumentOnly(BookFormat.pdf), isTrue);
      expect(service.hasReaderRoute(BookFormat.pdf), isTrue);
    });

    test('djvu is documentOnly', () {
      expect(service.capabilityOf(BookFormat.djvu), FormatCapability.documentOnly);
      expect(service.canReadInApp(BookFormat.djvu), isFalse);
      expect(service.isDocumentOnly(BookFormat.djvu), isTrue);
      expect(service.hasReaderRoute(BookFormat.djvu), isTrue);
    });

    test('unknown is unsupported', () {
      expect(service.capabilityOf(BookFormat.unknown), FormatCapability.unsupported);
      expect(service.canReadInApp(BookFormat.unknown), isFalse);
      expect(service.canImport(BookFormat.unknown), isFalse);
      expect(service.isDocumentOnly(BookFormat.unknown), isFalse);
      expect(service.hasReaderRoute(BookFormat.unknown), isFalse);
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
      expect(service.warningLabel(BookFormat.epub), isNull);
      expect(service.warningLabel(BookFormat.fb2), isNull);
      expect(service.warningLabel(BookFormat.txt), isNull);
      expect(service.warningLabel(BookFormat.rtf), isNull);
      expect(service.warningLabel(BookFormat.mobi), isNull);
    });

    test('non-null for documentOnly', () {
      expect(service.warningLabel(BookFormat.pdf), isNotNull);
      expect(service.warningLabel(BookFormat.djvu), isNotNull);
    });

    test('non-null for partial', () {
      expect(service.warningLabel(BookFormat.azw3), isNotNull);
      expect(service.warningLabel(BookFormat.azw3), contains('MOBI'));
    });

    test('non-null for legacy', () {
      expect(service.warningLabel(BookFormat.prc), isNotNull);
      expect(service.warningLabel(BookFormat.prc), contains('legacy'));
    });

    test('non-null for unsupported', () {
      expect(service.warningLabel(BookFormat.unknown), isNotNull);
      expect(service.warningLabel(BookFormat.unknown), contains('не поддерживается'));
    });
  });

  group('all formats covered', () {
    test('every BookFormat has a defined capability', () {
      for (final format in BookFormat.values) {
        expect(
          () => service.capabilityOf(format),
          returnsNormally,
          reason: 'format ${format.name} should have a capability',
        );
      }
    });
  });
}
