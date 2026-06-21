import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../../core/formats/book_file_size_policy.dart';
import '../../../../core/formats/format_capability.dart';
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

    final fileSize = await file.length();
    final format = formatDetector.detect(path: path, bytes: const []);
    if (isBookFileTooLarge(format, fileSize)) {
      return BookFileInspectionResult(
        path: path,
        format: format,
        decision: ImportDecision.corrupted,
        hash: '',
        fileSize: fileSize,
        reason: bookFileTooLargeMessage(format, fileSize),
      );
    }

    final hash = await _computeStreamHash(file);

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

    const maxMetadataBytes = 256 * 1024;
    final metadataBytes = await _readFileHead(file, maxMetadataBytes);

    final metadata = await metadataExtractor.extract(
      path: path,
      bytes: metadataBytes,
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
    final capService = const FormatCapabilityService();
    if (capService.isDocumentOnly(format)) {
      return ImportDecision.importAsDocument;
    }
    if (format == BookFormat.epub || format == BookFormat.fb2) {
      if (metadata.encodingConfidence != null && metadata.encodingConfidence! < 0.55) {
        return ImportDecision.needsEncodingSelection;
      }
    }
    if (capService.canReadInApp(format)) {
      return ImportDecision.importAsBook;
    }
    return ImportDecision.unsupported;
  }

  Future<String> _computeStreamHash(File file) async {
    final digest = await sha256.bind(file.openRead()).last;
    return digest.toString();
  }

  Future<Uint8List> _readFileHead(File file, int maxBytes) async {
    final raf = await file.open();
    try {
      final length = await raf.length();
      final toRead = length < maxBytes ? length : maxBytes;
      return await raf.read(toRead);
    } finally {
      await raf.close();
    }
  }
}
