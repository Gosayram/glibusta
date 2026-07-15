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
  test('parses XHTML with a UTF-8 BOM without exposing it in text', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_bom_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );

      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '\uFEFF<html><body><p>BOM-safe text</p></body></html>',
      );

      final paragraph = parsed.blocks.single as ParagraphBlock;
      expect(paragraph.spans.map((span) => span.text).join(), 'BOM-safe text');
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

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

  test('extracts the local audio file referenced by a SMIL media overlay', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_audio_test_');
    try {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'META-INF/container.xml',
            '''
              <container><rootfiles>
                <rootfile full-path="OEBPS/content.opf"/>
              </rootfiles></container>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/content.opf',
            '''
              <package><metadata><title>Audio EPUB</title></metadata><manifest>
                <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
                <item id="overlay" href="audio/overlay.smil" media-type="application/smil+xml"/>
                <item id="audio" href="audio/chapter.mp3" media-type="audio/mpeg"/>
              </manifest><spine><itemref idref="chapter" media-overlay="overlay"/></spine></package>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/chapter.xhtml',
            '<html><body><p id="p1">Narrated paragraph</p></body></html>',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/audio/overlay.smil',
            '''
              <smil><body><par>
                <text src="../chapter.xhtml#p1"/>
                <audio src="chapter.mp3" clipBegin="0s" clipEnd="2s"/>
              </par></body></smil>''',
          ),
        )
        ..addFile(ArchiveFile('OEBPS/audio/chapter.mp3', 3, [1, 2, 3]));
      final file = File('${temporaryDirectory.path}/audio.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final book = await CustomEpubParser(
        imageStore: EpubImageStore(temporaryDirectory),
      ).parse(file.path);
      final entry = book.chapters.single.smilEntries!.single;

      expect(await File(entry.audioSrc).readAsBytes(), [1, 2, 3]);
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
            <p class="centered" style="text-indent: 24px; font-size: 21px">Paragraph</p>
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
      expect(block.fontSize, 21);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('preserves an EPUB RTL direction in normalized metadata', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_rtl_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '<html dir="rtl"><body><p>مرحبا بالعالم</p></body></html>',
      );

      final normalized = EpubBookAdapter().toNormalizedBook(
        EpubBook(
          title: 'RTL EPUB',
          authors: const [],
          chapters: [
            EpubChapter(
              id: 'chapter',
              href: 'chapter.xhtml',
              title: 'Chapter',
              blocks: parsed.blocks,
              styles: parsed.styles,
              textDirection: parsed.textDirection,
            ),
          ],
          resources: const {},
          textDirection: parsed.textDirection,
        ),
        'rtl',
      );

      expect(normalized.metadata?['textDirection'], 'rtl');
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('parses a ruby-heavy XHTML chapter repeatedly without retaining parser state', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_ruby_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final ruby = List<String>.filled(2000, '<ruby>漢<rt>かん</rt></ruby>').join();
      final html = '<html><body><p>$ruby</p></body></html>';

      final first = await parser.parseChapter(chapterPath: 'chapter.xhtml', htmlText: html);
      final second = await parser.parseChapter(chapterPath: 'chapter.xhtml', htmlText: html);

      final firstParagraph = first.blocks.single as ParagraphBlock;
      final secondParagraph = second.blocks.single as ParagraphBlock;
      final firstText = firstParagraph.spans.map((span) => span.text).join();
      final secondText = secondParagraph.spans.map((span) => span.text).join();

      expect(firstText, secondText);
      expect(secondText, contains('漢'));
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
