import 'dart:async';
import 'dart:typed_data';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../reader/data/parsers/format_detector.dart';
import '../../../reader/data/parsers/parser_registry.dart';

final class BookMetadataExtractor {
  static const _metadataTimeout = Duration(seconds: 12);

  final _registry = BookParserRegistry.defaultInstance;

  Future<BookMetadata> extract({
    required String path,
    required Uint8List bytes,
    required BookFormat format,
    required BookEncodingDetector encodingDetector,
  }) async {
    if (format == BookFormat.unknown || format == BookFormat.pdf || format == BookFormat.djvu) {
      return const BookMetadata();
    }

    final parser = _registry.parserForFormat(format);
    if (parser == null) {
      return const BookMetadata();
    }

    try {
      final fileName = path.split('/').last;
      EncodingDetectionResult? detectedEncoding;
      try {
        detectedEncoding = await _detectTextEncoding(
          bytes: bytes,
          fileName: fileName,
          format: format,
          encodingDetector: encodingDetector,
        );
      } on TimeoutException {
        // Encoding detection timed out — proceed without forced encoding.
      } on Object catch (_) {
        // Encoding detection failed — proceed without forced encoding.
      }
      final book = await parser
          .parse(
            bytes,
            fileName: fileName,
            forcedEncoding: detectedEncoding?.encoding,
          )
          .timeout(_metadataTimeout);
      return BookMetadata(
        title: _fallbackTitle(book.title, fileName),
        authors: book.authors,
        description: book.description,
        encoding: detectedEncoding?.encoding,
        encodingConfidence: detectedEncoding?.confidence,
      );
    } on TimeoutException {
      return BookMetadata(
        title: _titleFromPath(path),
        isCorrupted: true,
        error: 'Не удалось быстро прочитать метаданные: превышен таймаут',
      );
    } on Object catch (e) {
      return BookMetadata(
        title: _titleFromPath(path),
        isCorrupted: true,
        error: e.toString(),
      );
    }
  }

  Future<EncodingDetectionResult?> _detectTextEncoding({
    required Uint8List bytes,
    required String fileName,
    required BookFormat format,
    required BookEncodingDetector encodingDetector,
  }) async {
    if (format != BookFormat.fb2 && format != BookFormat.txt && format != BookFormat.rtf) {
      return null;
    }
    return encodingDetector.detect(bytes, fileName: fileName).timeout(_metadataTimeout);
  }

  String _fallbackTitle(String title, String fileName) {
    final cleaned = title.trim();
    if (cleaned.isNotEmpty && cleaned != 'Без названия') {
      return cleaned;
    }
    return _titleFromFileName(fileName);
  }

  String _titleFromPath(String path) => _titleFromFileName(path.split('/').last);

  String _titleFromFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
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
