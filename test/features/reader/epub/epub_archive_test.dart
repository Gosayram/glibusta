import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/epub/epub_archive.dart';

void main() {
  test('opens an EPUB archive without inflating entries eagerly', () async {
    final directory = await Directory.systemTemp.createTemp('epub_archive_test_');
    try {
      final archive = Archive()
        ..addFile(ArchiveFile.string('OEBPS/chapter.xhtml', '<p>Readable</p>'));
      final file = File('${directory.path}/book.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final epub = await EpubArchive.open(file.path);

      expect(epub.readText('OEBPS/chapter.xhtml'), '<p>Readable</p>');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rejects an EPUB archive with too many entries before parsing chapters', () async {
    final directory = await Directory.systemTemp.createTemp('epub_archive_limit_test_');
    try {
      final archive = Archive();
      for (var index = 0; index <= 1000; index++) {
        archive.addFile(ArchiveFile.bytes('OEBPS/$index.xhtml', const [0]));
      }
      final file = File('${directory.path}/too-many-entries.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive));

      await expectLater(EpubArchive.open(file.path), throwsStateError);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
