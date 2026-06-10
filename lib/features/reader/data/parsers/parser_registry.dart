import 'book_parser.dart';
import 'format_detector.dart';

final class BookParserRegistry {
  BookParserRegistry(this._parsers);

  final List<BookParser> _parsers;

  BookParser parserFor(BookFormat format) {
    for (final parser in _parsers) {
      if (parser.supports(format)) return parser;
    }
    throw UnsupportedError('No parser for format: $format');
  }

  bool hasParser(BookFormat format) {
    return _parsers.any((p) => p.supports(format));
  }
}
