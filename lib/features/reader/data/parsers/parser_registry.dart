import 'book_parser.dart';
import 'cbz_parser.dart';
import 'format_detector.dart';
import 'rust_book_parser.dart';

/// LW-13.1: Plugin-capable parser registry.
/// Parsers can be registered dynamically at runtime.
final class BookParserRegistry {
  BookParserRegistry(List<BookParser> parsers) : _parsers = List.of(parsers);

  final List<BookParser> _parsers;

  static final BookParserRegistry defaultInstance = BookParserRegistry([
    RustBookParser(),
    CbzParser(),
  ]);

  /// Register a new parser at runtime (LW-13.1 plugin support).
  void register(BookParser parser) {
    _parsers.add(parser);
  }

  /// Unregister a parser.
  bool unregister(BookParser parser) => _parsers.remove(parser);

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

  /// All registered parsers (read-only view).
  List<BookParser> get parsers => List.unmodifiable(_parsers);
}
