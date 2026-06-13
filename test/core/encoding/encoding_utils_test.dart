import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/encoding/encoding_utils.dart'
    as enc
    show
        decodeUtf16Le,
        decodeUtf16Be,
        detectDeclaredEncoding,
        normalizeEncodingName;

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

void main() {
  group('startsWith', () {
    test('returns true for matching prefix', () {
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x48]);
      expect(_startsWith(bytes, [0xEF, 0xBB, 0xBF]), isTrue);
    });

    test('returns false for non-matching prefix', () {
      final bytes = Uint8List.fromList([0x48, 0x65]);
      expect(_startsWith(bytes, [0xEF, 0xBB, 0xBF]), isFalse);
    });

    test('returns false when bytes shorter than prefix', () {
      final bytes = Uint8List.fromList([0xEF]);
      expect(_startsWith(bytes, [0xEF, 0xBB, 0xBF]), isFalse);
    });

    test('empty bytes with empty prefix returns true', () {
      expect(_startsWith(Uint8List(0), []), isTrue);
    });
  });

  group('decodeUtf16Le', () {
    test('decodes ASCII text', () {
      final bytes = Uint8List.fromList([0x48, 0x00, 0x69, 0x00]);
      expect(enc.decodeUtf16Le(bytes), 'Hi');
    });

    test('decodes Cyrillic text', () {
      final realBytes = <int>[
        0x1F, 0x04,
        0x40, 0x04,
        0x38, 0x04,
        0x32, 0x04,
        0x35, 0x04,
        0x42, 0x04,
      ];
      final result = enc.decodeUtf16Le(Uint8List.fromList(realBytes));
      expect(result, 'Привет');
    });

    test('empty bytes returns empty string', () {
      expect(enc.decodeUtf16Le(Uint8List(0)), '');
    });

    test('odd byte length ignores last byte', () {
      final bytes = Uint8List.fromList([0x48, 0x00, 0x69]);
      expect(enc.decodeUtf16Le(bytes), 'H');
    });
  });

  group('decodeUtf16Be', () {
    test('decodes ASCII text', () {
      final bytes = Uint8List.fromList([0x00, 0x48, 0x00, 0x69]);
      expect(enc.decodeUtf16Be(bytes), 'Hi');
    });

    test('empty bytes returns empty string', () {
      expect(enc.decodeUtf16Be(Uint8List(0)), '');
    });
  });

  group('detectDeclaredEncoding', () {
    test('detects encoding from XML declaration', () {
      final xml = '<?xml version="1.0" encoding="windows-1251"?>\n<root/>'
          .codeUnits;
      final result = enc.detectDeclaredEncoding(Uint8List.fromList(xml));
      expect(result, 'windows-1251');
    });

    test('detects encoding from HTML meta charset', () {
      final html = '<html><head><meta charset="utf-8"></head></html>'
          .codeUnits;
      final result = enc.detectDeclaredEncoding(Uint8List.fromList(html));
      expect(result, 'utf-8');
    });

    test('detects encoding from Content-Type meta', () {
      final html =
          '<meta http-equiv="Content-Type" content="text/html; charset=koi8-r">'
              .codeUnits;
      final result = enc.detectDeclaredEncoding(Uint8List.fromList(html));
      expect(result, 'koi8-r');
    });

    test('returns null when no encoding declared', () {
      final html = '<html><head></head></html>'.codeUnits;
      final result = enc.detectDeclaredEncoding(Uint8List.fromList(html));
      expect(result, isNull);
    });
  });

  group('normalizeEncodingName', () {
    test('normalizes utf8 to utf-8', () {
      expect(enc.normalizeEncodingName('utf8'), 'utf-8');
    });

    test('normalizes utf-16 to utf-16le', () {
      expect(enc.normalizeEncodingName('utf-16'), 'utf-16le');
    });

    test('normalizes utf-16-be to utf-16be', () {
      expect(enc.normalizeEncodingName('utf-16-be'), 'utf-16be');
    });

    test('normalizes windows-1251 aliases', () {
      expect(enc.normalizeEncodingName('cp1251'), 'windows-1251');
      expect(enc.normalizeEncodingName('win1251'), 'windows-1251');
      expect(enc.normalizeEncodingName('WINDOWS-1251'), 'windows-1251');
    });

    test('normalizes ibm866 aliases', () {
      expect(enc.normalizeEncodingName('cp866'), 'ibm866');
      expect(enc.normalizeEncodingName('866'), 'ibm866');
    });

    test('normalizes koi8-r', () {
      expect(enc.normalizeEncodingName('koi8r'), 'koi8-r');
      expect(enc.normalizeEncodingName('KOI8-R'), 'koi8-r');
    });

    test('normalizes iso-8859-1', () {
      expect(enc.normalizeEncodingName('latin1'), 'iso-8859-1');
      expect(enc.normalizeEncodingName('iso8859-5'), 'iso-8859-5');
    });

    test('trims whitespace and lowercases', () {
      expect(enc.normalizeEncodingName('  UTF-8  '), 'utf-8');
    });

    test('replaces underscores with hyphens', () {
      expect(enc.normalizeEncodingName('utf_8'), 'utf-8');
    });

    test('unknown encoding passed through', () {
      expect(enc.normalizeEncodingName('some-new-encoding'), 'some-new-encoding');
    });
  });
}
