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
}
