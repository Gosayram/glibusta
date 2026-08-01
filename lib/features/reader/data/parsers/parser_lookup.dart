import 'book_parser.dart';
import 'cbz_parser.dart';
import 'format_detector.dart';
import 'rust_book_parser.dart';

final Map<BookFormat, BookParser> parserForFormatMap = {
  for (final p in [RustBookParser(), CbzParser()])
    for (final f in BookFormat.values)
      if (p.supports(f)) f: p,
};

BookParser? lookupParserForFormat(BookFormat format) =>
    parserForFormatMap[format];

BookParser lookupParserFor(BookFormat format) =>
    parserForFormatMap[format] ??
    (throw UnsupportedError('No parser for format: ${format.name}'));

BookParser? lookupParserForExtension(String ext) {
  final format = formatForExtension(ext);
  if (format == BookFormat.unknown) return null;
  return lookupParserForFormat(format);
}
