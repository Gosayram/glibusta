import '../../features/reader/data/parsers/rtf_parser.dart';
import '../../shared/models/book.dart';
import 'reader_document.dart';

final class RtfFormatHandler {
  RtfFormatHandler({RtfBookParser? parser}) : _parser = parser ?? RtfBookParser();

  final RtfBookParser _parser;

  bool supports(BookFormat format) => format == BookFormat.rtf;

  Future<ReaderDocument> prepare(String path) async {
    final book = await _parser.parseFile(path);
    return ReaderDocument(
      title: book.title,
      format: BookFormat.rtf,
      authors: book.authors,
      description: book.description,
      chapters: book.chapters,
    );
  }
}
