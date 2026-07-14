import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/epub/epub_toc_parser.dart';

void main() {
  group('parseNavToc', () {
    test('selects the EPUB3 TOC nav and preserves nested entries', () {
      const navDocument = '''
<html xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="landmarks"><ol><li><a href="cover.xhtml">Cover</a></li></ol></nav>
    <nav epub:type="toc">
      <ol>
        <li>
          <a href="chapter-1.xhtml">Chapter 1</a>
          <ol><li><a href="chapter-1.xhtml#part-1">Part 1</a></li></ol>
        </li>
      </ol>
    </nav>
  </body>
</html>''';

      final toc = parseNavToc(navDocument);

      expect(toc, hasLength(1));
      expect(toc.single.title, 'Chapter 1');
      expect(toc.single.href, 'chapter-1.xhtml');
      expect(toc.single.children, hasLength(1));
      expect(toc.single.children.single.title, 'Part 1');
      expect(toc.single.children.single.href, 'chapter-1.xhtml#part-1');
    });
  });

  group('parseNcx', () {
    test('preserves the hierarchy of an EPUB2 NCX table of contents', () {
      const ncxDocument = '''
<ncx>
  <navMap>
    <navPoint>
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter-1.xhtml" />
      <navPoint>
        <navLabel><text>Part 1</text></navLabel>
        <content src="chapter-1.xhtml#part-1" />
      </navPoint>
    </navPoint>
  </navMap>
</ncx>''';

      final toc = parseNcx(ncxDocument);

      expect(toc, hasLength(1));
      expect(toc.single.title, 'Chapter 1');
      expect(toc.single.href, 'chapter-1.xhtml');
      expect(toc.single.children, hasLength(1));
      expect(toc.single.children.single.title, 'Part 1');
      expect(toc.single.children.single.href, 'chapter-1.xhtml#part-1');
    });
  });
}
