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

  test('keeps numeric in-book links as ordinary link spans', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_numeric_link_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );

      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html><body><p>See <a href="#12">12</a> and
          <a href="chapter.xhtml#verse-3">3</a>.</p></body></html>
        ''',
      );

      final paragraph = parsed.blocks.single as ParagraphBlock;
      expect(
        paragraph.spans.where((span) => span.href != null).map((span) => span.href),
        <String?>['#12', 'chapter.xhtml#verse-3'],
      );
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('does not turn active markup or footnote backgrounds into reader blocks', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_active_markup_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );

      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html xmlns:epub="http://www.idpf.org/2007/ops"><head><style>
            .footnote { background-image: url('tracking.png'); }
          </style></head><body>
            <p>Visible <script>alert('not reader text')</script><iframe
              srcdoc="&lt;p&gt;active&lt;/p&gt;">fallback frame text</iframe> prose.</p>
            <aside epub:type="footnote" class="footnote"><p>Legitimate footnote.</p></aside>
          </body></html>
        ''',
      );
      final text = parsed.blocks
          .whereType<ParagraphBlock>()
          .expand((block) => block.spans)
          .map((span) => span.text)
          .join('\n');

      expect(text, contains('Visible'));
      expect(text, contains('prose.'));
      expect(text, contains('Legitimate footnote.'));
      expect(text, isNot(contains("alert('not reader text')")));
      expect(text, isNot(contains('fallback frame text')));
      expect(parsed.blocks.whereType<ImageBlock>(), isEmpty);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('keeps tables and absolute-positioned text in the reflow block stream', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_reflow_table_test_');
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
            .margin-note { position: absolute; left: 40px; top: 10px; }
          </style></head><body>
            <p>Opening prose.</p>
            <p class="margin-note">Margin note remains readable.</p>
            <table><tbody>
              <tr><th>Term</th><th>Definition</th></tr>
              <tr><td>EPUB</td><td>Reflowable publication</td></tr>
            </tbody></table>
            <p>Closing prose.</p>
          </body></html>
        ''',
      );

      final table = parsed.blocks.whereType<TableBlock>().single;
      expect(
        table.rows,
        <List<String>>[
          <String>['Term', 'Definition'],
          <String>['EPUB', 'Reflowable publication'],
        ],
      );
      expect(
        parsed.blocks
            .whereType<ParagraphBlock>()
            .expand((block) => block.spans)
            .map(
              (span) => span.text,
            ),
        contains('Margin note remains readable.'),
      );
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

  test('does not expose an SVG cover wrapper as a second reader chapter', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_svg_cover_test_');
    try {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'META-INF/container.xml',
            '''<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/content.opf',
            '''<package><metadata><title>SVG cover</title><meta name="cover" content="cover-image"/></metadata><manifest><item id="cover-image" href="images/cover.svg" media-type="image/svg+xml"/><item id="cover-page" href="cover.xhtml" media-type="application/xhtml+xml"/><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="cover-page"/><itemref idref="chapter"/></spine></package>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/images/cover.svg',
            '<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/cover.xhtml',
            '''<html><body><svg xmlns="http://www.w3.org/2000/svg"><image href="images/cover.svg"/></svg></body></html>''',
          ),
        )
        ..addFile(
          ArchiveFile.string(
            'OEBPS/chapter.xhtml',
            '<html><body><p>Actual chapter text.</p></body></html>',
          ),
        );
      final file = File('${temporaryDirectory.path}/svg-cover.epub');
      await file.writeAsBytes(ZipEncoder().encode(archive));

      final book = await CustomEpubParser(
        imageStore: EpubImageStore(temporaryDirectory),
      ).parse(file.path);

      expect(book.coverImagePath, endsWith('.svg'));
      expect(book.chapters, hasLength(1));
      final paragraph = book.chapters.single.blocks.single as ParagraphBlock;
      expect(paragraph.spans.single.text, 'Actual chapter text.');
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

  test('applies CSS specificity and source order independently of class order', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_css_cascade_test_');
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
            p { text-align: left; }
            p.emphasis { text-align: right; }
            .notice { text-align: center; }
            .notice { text-indent: 1em; }
            .notice { text-indent: 2em; }
          </style></head><body><p class="emphasis notice">Paragraph</p></body></html>
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

      expect(block.textAlign, TextAlign.right);
      expect(block.textIndent, 32);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('includes linked stylesheets in the chapter CSS cascade', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_linked_css_test_');
    try {
      final archive = Archive()
        ..addFile(ArchiveFile.string('OEBPS/styles/book.css', '.notice { text-align: center; }'));
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver({
          'styles': const EpubResource(
            id: 'styles',
            href: 'styles/book.css',
            fullPath: 'OEBPS/styles/book.css',
            mediaType: 'text/css',
            properties: {},
            type: EpubResourceType.css,
          ),
        }),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(archive),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'OEBPS/text/chapter.xhtml',
        htmlText: '''
          <html><head><link rel="stylesheet" href="../styles/book.css" /></head>
          <body><p class="notice">Paragraph</p></body></html>
        ''',
      );

      final normalized = EpubBookAdapter().toNormalizedBook(
        EpubBook(
          title: 'Test',
          authors: const [],
          chapters: [
            EpubChapter(
              id: 'chapter',
              href: 'text/chapter.xhtml',
              title: 'Chapter',
              blocks: parsed.blocks,
              styles: parsed.styles,
            ),
          ],
          resources: const {},
        ),
        'test',
      );

      expect(normalized.chapters.single.blocks.single.textAlign, TextAlign.center);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('ignores CSS comments when matching paragraph selectors', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_css_comment_test_');
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
            /* Exported by a common EPUB generator. */
            .notice { text-align: center; }
          </style></head><body><p class="notice">Paragraph</p></body></html>
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

      expect(normalized.chapters.single.blocks.single.textAlign, TextAlign.center);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('converts rem font sizes from EPUB CSS', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_css_rem_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html><head><style>p { font-size: 1.25rem; }</style></head>
          <body><p>Paragraph</p></body></html>
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

      expect(normalized.chapters.single.blocks.single.fontSize, 20);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('matches CSS property names case-insensitively', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'epub_css_property_case_test_',
    );
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html><head><style>p { TEXT-ALIGN: center; FONT-SIZE: 20PX; }</style></head>
          <body><p>Paragraph</p></body></html>
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

      expect(block.textAlign, TextAlign.center);
      expect(block.fontSize, 20);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('applies supported media-query CSS rules', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_css_media_test_');
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
            @media screen { p { text-align: justify; } }
          </style></head><body><p>Paragraph</p></body></html>
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

      expect(normalized.chapters.single.blocks.single.textAlign, TextAlign.justify);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('assigns unique block indices after flattening section content', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_section_index_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );
      final parsed = await parser.parseChapter(
        chapterPath: 'chapter.xhtml',
        htmlText: '''
          <html><body>
            <p>Before</p><div><p>Inside one</p><p>Inside two</p></div><p>After</p>
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
            ),
          ],
          resources: const {},
        ),
        'test',
      );

      expect(normalized.chapters.single.blocks.map((block) => block.index), [0, 1, 2, 3]);
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
