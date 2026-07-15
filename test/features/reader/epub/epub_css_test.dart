import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/epub/epub_archive.dart';
import 'package:glibusta/features/reader/epub/epub_book_adapter.dart';
import 'package:glibusta/features/reader/epub/epub_html_parser.dart';
import 'package:glibusta/features/reader/epub/epub_image_store.dart';
import 'package:glibusta/features/reader/epub/epub_models.dart';
import 'package:glibusta/features/reader/epub/epub_parser.dart';
import 'package:glibusta/features/reader/epub/epub_resource_resolver.dart';

void main() {
  test('recovers an EPUB with a missing mimetype entry when its container is valid', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_recovery_test_');
    try {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'META-INF/container.xml',
            '''
              <?xml version="1.0"?>
              <container><rootfiles>
                <rootfile full-path="OEBPS/content.opf"/>
              </rootfiles></container>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/content.opf',
            '''
              <?xml version="1.0"?>
              <package><metadata>
                <title>Recovered EPUB</title><creator>Author</creator>
              </metadata><manifest>
                <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
              </manifest><spine><itemref idref="chapter"/></spine></package>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/chapter.xhtml',
            '<html><body><p>Readable chapter</p></body></html>',
          ),
        );
      final file = File('${temporaryDirectory.path}/missing-mimetype.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final book = await CustomEpubParser(
        imageStore: EpubImageStore(temporaryDirectory),
      ).parse(file.path);

      expect(book.title, 'Recovered EPUB');
      expect(book.chapters.single.blocks, isNotEmpty);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('applies class and inline paragraph CSS layout properties', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_css_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html><head><style>
            p { text-indent: 1em; }
            .centered { text-align: center; }
            p.centered { text-indent: 2em; }
          </style></head><body>
            <p class="centered" style="text-indent: 24px">Paragraph</p>
          </body></html>
        ''',
      );

      final normalized = EpubBookAdapter().toNormalizedBook(
        EpubBook(
          title: 'Test',
          authors: const [],
          chapters: [
            EpubChapter(
              id: 'chapter',
              href: 'chapter.xhtml',
              title: 'Chapter',
              blocks: parsed.blocks,
              styles: parsed.styles,
            ),
          ],
          resources: const {},
        ),
        'test',
      );
      final block = normalized.chapters.single.blocks.single;

      expect(block.text, 'Paragraph');
      expect(block.textAlign, TextAlign.center);
      expect(block.textIndent, 24);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
