import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/formats/rtf_format_handler.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  test('RtfFormatHandler prepares ReaderDocument', () async {
    final dir = await Directory.systemTemp.createTemp('rtf_handler_');
    try {
      final file = File('${dir.path}/sample.rtf');
      await file.writeAsString(r'{\rtf1 Test\par Body}');

      final document = await RtfFormatHandler().prepare(file.path);

      expect(document.format, BookFormat.rtf);
      expect(document.title, 'sample');
      expect(document.chapters, isNotEmpty);
      expect(document.toNormalizedBook('id').metadata?['format'], 'rtf');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
