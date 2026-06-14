import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../reader/data/parsers/format_detector.dart';
import 'book_format_detector.dart';
import 'book_inspection_result.dart';
import 'book_metadata_extractor.dart';
import 'duplicate_checker.dart';

final class BookFileInspector {
  BookFileInspector({
    required this.formatDetector,
    required this.encodingDetector,
    required this.metadataExtractor,
    required this.duplicateChecker,
  });

  final BookFormatDetector formatDetector;
  final BookEncodingDetector encodingDetector;
  final BookMetadataExtractor metadataExtractor;
  final DuplicateChecker duplicateChecker;

  Future<BookFileInspectionResult> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return BookFileInspectionResult(
        path: path,
        format: BookFormat.unknown,
        decision: ImportDecision.corrupted,
        hash: '',
        reason: 'Файл не найден',
      );
    }

    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final fileSize = bytes.length;

    final isDuplicate = await duplicateChecker.exists(hash);
    if (isDuplicate) {
      return BookFileInspectionResult(
        path: path,
        format: BookFormat.unknown,
        decision: ImportDecision.duplicate,
        hash: hash,
        fileSize: fileSize,
        reason: 'Такая книга уже есть в библиотеке',
      );
    }

    final format = formatDetector.detect(path: path, bytes: bytes);

    final metadata = await metadataExtractor.extract(
      path: path,
      bytes: Uint8List.fromList(bytes),
      format: format,
      encodingDetector: encodingDetector,
    );

    final decision = _decide(format: format, metadata: metadata);

    return BookFileInspectionResult(
      path: path,
      format: format,
      decision: decision,
      hash: hash,
      title: metadata.title,
      authors: metadata.authors,
      encoding: metadata.encoding,
      encodingConfidence: metadata.encodingConfidence,
      fileSize: fileSize,
      reason: metadata.error,
    );
  }

  ImportDecision _decide({
    required BookFormat format,
    required BookMetadata metadata,
  }) {
    if (metadata.isCorrupted) {
      return ImportDecision.corrupted;
    }
    if (format == BookFormat.pdf || format == BookFormat.djvu) {
      return ImportDecision.importAsDocument;
    }
    if (format == BookFormat.epub || format == BookFormat.fb2) {
      if (metadata.encodingConfidence != null && metadata.encodingConfidence! < 0.55) {
        return ImportDecision.needsEncodingSelection;
      }
      return ImportDecision.importAsBook;
    }
    if (format == BookFormat.txt || format == BookFormat.rtf) {
      return ImportDecision.importAsBook;
    }
    return ImportDecision.unsupported;
  }
}
