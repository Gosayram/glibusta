import '../../../reader/data/parsers/format_detector.dart';

enum ImportDecision {
  importAsBook,
  importAsDocument,
  unsupported,
  corrupted,
  duplicate,
  needsEncodingSelection,
}

final class BookFileInspectionResult {
  const BookFileInspectionResult({
    required this.path,
    required this.format,
    required this.decision,
    required this.hash,
    this.title,
    this.authors = const [],
    this.encoding,
    this.encodingConfidence,
    this.fileSize,
    this.reason,
  });

  final String path;
  final BookFormat format;
  final ImportDecision decision;
  final String hash;
  final String? title;
  final List<String> authors;
  final String? encoding;
  final double? encodingConfidence;
  final int? fileSize;
  final String? reason;
}
