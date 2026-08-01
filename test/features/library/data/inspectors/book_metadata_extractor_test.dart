import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/encoding/encoding_detection.dart';
import 'package:glibusta/features/library/data/inspectors/book_metadata_extractor.dart';
import 'package:glibusta/features/reader/data/parsers/book_parser.dart';
import 'package:glibusta/features/reader/data/parsers/format_detector.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';

void main() {
  test('uses a filename fallback instead of parsing a truncated archive sample', () async {
    final parser = _RecordingEpubParser();
    final extractor = BookMetadataExtractor(
      parser: parser,
    );

    final metadata = await extractor.extract(
      path: '/books/large-book.epub',
      bytes: Uint8List(256 * 1024),
      format: BookFormat.epub,
      encodingDetector: BookEncodingDetector(),
      isCompleteFile: false,
    );

    expect(metadata.title, 'large-book');
    expect(metadata.isCorrupted, isFalse);
    expect(parser.parseCalls, 0);
  });
}

final class _RecordingEpubParser implements BookParser {
  int parseCalls = 0;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    parseCalls++;
    return const NormalizedBook(id: 'book', title: 'Parsed', authors: []);
  }

  @override
  Future<NormalizedBook> parseFile(String filePath, {String? forcedEncoding}) =>
      throw UnimplementedError();

  @override
  bool supports(BookFormat format) => format == BookFormat.epub;
}
