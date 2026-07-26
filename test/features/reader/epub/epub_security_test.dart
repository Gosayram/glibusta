import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/epub/epub_archive.dart';
import 'package:glibusta/features/reader/epub/epub_html_parser.dart';
import 'package:glibusta/features/reader/epub/epub_image_store.dart';
import 'package:glibusta/features/reader/epub/epub_models.dart';
import 'package:glibusta/features/reader/epub/epub_resource_resolver.dart';

void main() {
  test('ignores active EPUB links and non-archive image sources', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp('epub_security_test_');
    try {
      final parser = EpubHtmlParser(
        resolver: EpubResourceResolver(const {}),
        imageStore: EpubImageStore(temporaryDirectory),
        epub: EpubArchive(Archive()),
      );

      final parsed = await parser.parseChapter(
        chapterPath: 'OEBPS/text/chapter.xhtml',
        htmlText: '''
          <html><body>
            <p><a href="#note">Local</a><a href="https://example.test/reference">Web</a>
            <a href="java&#x0A;script:alert(1)">Script</a><a href="vbscript:msgbox(1)">VB</a>
            <a href="data:text/html,unsafe">Data</a><a href="file:///private/secret">File</a></p>
            <img src="https://example.test/pixel.png"/><img src="file:///private/secret.png"/>
          </body></html>
        ''',
      );

      final paragraph =
          parsed.blocks.singleWhere((block) => block is ParagraphBlock) as ParagraphBlock;
      expect(
        paragraph.spans.where((span) => span.href != null).map((span) => span.href),
        <String?>['#note', 'https://example.test/reference'],
      );
      expect(parsed.blocks.whereType<ImageBlock>(), isEmpty);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('resource resolver never resolves URI-scheme sources from an EPUB', () {
    const resource = EpubResource(
      id: 'image',
      href: 'image.png',
      fullPath: 'OEBPS/text/image.png',
      mediaType: 'image/png',
      properties: {},
      type: EpubResourceType.image,
    );
    final resolver = EpubResourceResolver({'image': resource});

    for (final href in const [
      'https://example.test/image.png',
      'file:///private/image.png',
      'data:image/png;base64,AA==',
    ]) {
      expect(
        resolver.resolveFromHref(chapterPath: 'OEBPS/text/chapter.xhtml', href: href),
        isNull,
        reason: href,
      );
    }
  });
}
