import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' show Document;
import 'package:html/parser.dart' show parse;

const _formatUrlPattern = r'/b/\d+/(\w+)';

void main() {
  group('Flibusta parsing edge cases', () {
    group('format URL regex handles query parameters', () {
      test('matches plain format URL', () {
        final href = '/b/12345/epub';
        final match = RegExp(_formatUrlPattern).firstMatch(href);
        expect(match?.group(1), 'epub');
      });

      test('matches format URL with query parameter', () {
        final href = '/b/12345/epub?from=main';
        final match = RegExp(_formatUrlPattern).firstMatch(href);
        expect(match?.group(1), 'epub');
      });

      test('matches format URL with multiple query parameters', () {
        final href = '/b/12345/fb2?utm_source=search&ref=book';
        final match = RegExp(_formatUrlPattern).firstMatch(href);
        expect(match?.group(1), 'fb2');
      });

      test('skips non-format endpoints', () {
        final href = '/b/12345/read';
        final match = RegExp(_formatUrlPattern).firstMatch(href);
        expect(match?.group(1), 'read');
      });

      test('skips download endpoint', () {
        final href = '/b/12345/download';
        final match = RegExp(_formatUrlPattern).firstMatch(href);
        expect(match?.group(1), 'download');
      });
    });

    group('description extraction handles div siblings', () {
      String buildHtml(List<String> parts) => parts.join();

      test('extracts description from <p> tags', () {
        final html = buildHtml([
          '<html><body>',
          '<h2>Аннотация:</h2>',
          '<p>First paragraph.</p>',
          '<p>Second paragraph.</p>',
          '<h2>Содержание</h2>',
          '</body></html>',
        ]);
        final doc = parse(html);
        final description = _extractDescription(doc);
        expect(description, contains('First paragraph'));
        expect(description, contains('Second paragraph'));
      });

      test('extracts description from <div> tags', () {
        final html = buildHtml([
          '<html><body>',
          '<h2>Аннотация:</h2>',
          '<div>First paragraph.</div>',
          '<div>Second paragraph.</div>',
          '<h2>Содержание</h2>',
          '</body></html>',
        ]);
        final doc = parse(html);
        final description = _extractDescription(doc);
        expect(description, contains('First paragraph'));
        expect(description, contains('Second paragraph'));
      });

      test('extracts mixed p and div siblings', () {
        final html = buildHtml([
          '<html><body>',
          '<h2>Аннотация:</h2>',
          '<p>Paragraph one.</p>',
          '<div>Div content.</div>',
          '<p>Paragraph two.</p>',
          '<h2>Содержание</h2>',
          '</body></html>',
        ]);
        final doc = parse(html);
        final description = _extractDescription(doc);
        expect(description, contains('Paragraph one'));
        expect(description, contains('Div content'));
        expect(description, contains('Paragraph two'));
      });

      test('ignores non p/div siblings like <ul>', () {
        final html = buildHtml([
          '<html><body>',
          '<h2>Аннотация:</h2>',
          '<p>Real description.</p>',
          '<ul><li>List item should not appear</li></ul>',
          '<p>More desc.</p>',
          '<h2>Содержание</h2>',
          '</body></html>',
        ]);
        final doc = parse(html);
        final description = _extractDescription(doc);
        expect(description, contains('Real description'));
        expect(description, contains('More desc'));
      });
    });

    group('format filtering in parseFormatUrls', () {
      test('filters out read/download/mail/complain links', () {
        final hrefs = [
          '/b/123/epub',
          '/b/123/fb2',
          '/b/123/read',
          '/b/123/download',
          '/b/123/mail',
          '/b/123/complain',
        ];
        final formats = <String>[];
        for (final href in hrefs) {
          final match = RegExp(_formatUrlPattern).firstMatch(href);
          if (match == null) continue;
          final fmt = match.group(1)!;
          if (fmt == 'read' || fmt == 'download' || fmt == 'mail' || fmt == 'complain') continue;
          formats.add(fmt);
        }
        expect(formats, contains('epub'));
        expect(formats, contains('fb2'));
        expect(formats, isNot(contains('read')));
        expect(formats, isNot(contains('download')));
        expect(formats, isNot(contains('mail')));
        expect(formats, isNot(contains('complain')));
      });

      test('formats list excludes action links even with query params', () {
        final hrefs = [
          '/b/123/epub',
          '/b/123/fb2?from=search',
          '/b/123/read?utm_source=main',
          '/b/123/epub?cover=true',
        ];
        final formats = <String>{};
        final seen = <String>{};
        for (final href in hrefs) {
          final match = RegExp(_formatUrlPattern).firstMatch(href);
          if (match == null) continue;
          final fmt = match.group(1)!;
          if (fmt == 'read' || fmt == 'download' || fmt == 'mail' || fmt == 'complain') continue;
          if (seen.add(fmt)) formats.add(fmt);
        }
        expect(formats, contains('epub'));
        expect(formats, contains('fb2'));
        expect(formats.length, 2);
      });
    });
  });
}

String _extractDescription(Document doc) {
  for (final h2 in doc.querySelectorAll('h2')) {
    if (h2.text.contains('Аннотация')) {
      final parts = <String>[];
      for (
        var sibling = h2.nextElementSibling;
        sibling != null && sibling.localName != 'h2';
        sibling = sibling.nextElementSibling
      ) {
        if (sibling.localName == 'p' || sibling.localName == 'div') {
          final text = sibling.text.trim();
          if (text.isNotEmpty) parts.add(text);
        }
      }
      return parts.join('\n\n');
    }
  }
  return '';
}
