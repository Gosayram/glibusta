import 'dart:typed_data';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../reader/data/parsers/book_parser.dart';
import '../../../reader/data/parsers/epub_parser.dart';
import '../../../reader/data/parsers/fb2_parser.dart';
import '../../../reader/data/parsers/format_detector.dart';
import '../../../reader/data/parsers/mobi_parser.dart';
import '../../../reader/data/parsers/rtf_parser.dart';
import '../../../reader/data/parsers/txt_parser.dart';

final class BookMetadataExtractor {
  final _parsers = <BookFormat, BookParser>{
    BookFormat.epub: EpubParser(),
    BookFormat.fb2: Fb2Parser(),
    BookFormat.txt: TxtBookParser(),
    BookFormat.rtf: RtfBookParser(),
    BookFormat.mobi: MobiBookParser(),
    BookFormat.azw3: MobiBookParser(),
    BookFormat.prc: MobiBookParser(),
  };

  Future<BookMetadata> extract({
    required String path,
    required Uint8List bytes,
    required BookFormat format,
    required BookEncodingDetector encodingDetector,
  }) async {
    if (format == BookFormat.unknown || format == BookFormat.pdf || format == BookFormat.djvu) {
      return const BookMetadata();
    }

    final parser = _parsers[format];
    if (parser == null) {
      return const BookMetadata();
    }

    try {
      final book = await parser.parse(
        bytes,
        fileName: path.split('/').last,
      );
      return BookMetadata(
        title: book.title,
        authors: book.authors,
        description: book.description,
      );
    } on Object catch (e) {
      return BookMetadata(
        isCorrupted: true,
        error: e.toString(),
      );
    }
  }
}

final class BookMetadata {
  const BookMetadata({
    this.title,
    this.authors = const [],
    this.description,
    this.encoding,
    this.encodingConfidence,
    this.isCorrupted = false,
    this.error,
  });

  final String? title;
  final List<String> authors;
  final String? description;
  final String? encoding;
  final double? encodingConfidence;
  final bool isCorrupted;
  final String? error;
}
