import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/rtf_parser.dart';

void main() {
  group('RtfBookParser', () {
    test('extracts plain text from basic RTF', () async {
      final parser = RtfBookParser();
      final bytes = Uint8List.fromList(
        utf8.encode(r'{\rtf1\ansi\b Title\b0\par First paragraph.\par Second paragraph.}'),
      );

      final book = await parser.parse(bytes, fileName: 'sample.rtf');

      expect(book.title, 'sample');
      expect(book.chapters, hasLength(1));
      expect(book.chapters.first.blocks.map((b) => b.text).join('\n'), contains('Title'));
      expect(
        book.chapters.first.blocks.map((b) => b.text).join('\n'),
        contains('First paragraph.'),
      );
      expect(
        book.chapters.first.blocks.map((b) => b.text).join('\n'),
        contains('Second paragraph.'),
      );
    });

    test('decodes unicode control words', () {
      expect(
        rtfToPlainText(r'{\rtf1 Hello \u1055?\u1088?\u1080?\u1074?\u1077?\u1090?}'),
        contains('Привет'),
      );
    });
  });

  group('rtfToPlainText safety limits', () {
    test('handles deeply nested groups without overflow', () {
      final rtf = '${'{' * 300}Hello${'}' * 300}';
      expect(() => rtfToPlainText(rtf), returnsNormally);
    });

    test('output is bounded by max output chars', () {
      final buffer = StringBuffer(r'{\rtf1 ');
      for (var i = 0; i < 1000000; i++) {
        buffer.write('A');
      }
      buffer.write('}');
      final result = rtfToPlainText(buffer.toString());
      expect(result.length, lessThan(6 * 1024 * 1024));
    });

    test('long control words are handled gracefully', () {
      final longWord = '\\${'a' * 200} ';
      final rtf = '{\\rtf1 $longWord Hello}';
      expect(rtfToPlainText(rtf), contains('Hello'));
    });

    test('unicode surrogates are skipped', () {
      expect(rtfToPlainText(r'{\rtf1 \u-10754?}'), isNot(contains('\uD800')));
    });

    test('unicode value out of range is skipped', () {
      expect(rtfToPlainText(r'{\rtf1 \u999999?}'), isNot(contains('???')));
    });
  });
}
