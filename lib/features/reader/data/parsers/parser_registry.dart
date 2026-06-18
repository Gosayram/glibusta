import 'book_parser.dart';
import 'cbz_parser.dart';
import 'docx_parser.dart';
import 'epub_parser.dart' as legacy_epub;
import 'fb2_parser.dart';
import 'format_detector.dart';
import 'mobi_parser.dart';
import 'rtf_parser.dart';
import 'txt_parser.dart';

final class BookParserRegistry {
  BookParserRegistry(this._parsers);

  final List<BookParser> _parsers;

  static final BookParserRegistry defaultInstance = BookParserRegistry([
    legacy_epub.EpubParser(),
    Fb2Parser(),
    TxtBookParser(),
    RtfBookParser(),
    MobiBookParser(),
    DocxParser(),
    CbzParser(),
  ]);

  BookParser parserFor(BookFormat format) {
    for (final parser in _parsers) {
      if (parser.supports(format)) return parser;
    }
    throw UnsupportedError('No parser for format: ${format.name}');
  }

  BookParser? parserForFormat(BookFormat format) {
    for (final parser in _parsers) {
      if (parser.supports(format)) return parser;
    }
    return null;
  }

  BookParser? parserForExtension(String ext) {
    final format = formatForExtension(ext);
    if (format == BookFormat.unknown) return null;
    return parserForFormat(format);
  }

  bool hasParser(BookFormat format) => parserForFormat(format) != null;
}
