import 'dart:typed_data';

import 'format_detector.dart';
import 'normalized_book.dart';

abstract class BookParser {
  bool supports(BookFormat format);

  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  });

  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  });
}

abstract class BookMetadataParser {
  Future<NormalizedBookMetadata?> parseMetadata(
    Uint8List bytes, {
    String? fileName,
  });
}
