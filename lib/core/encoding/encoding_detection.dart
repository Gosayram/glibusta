import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_charset/fl_charset.dart';
import 'package:flutter_charset_detector/flutter_charset_detector.dart';

import 'encoding_quality.dart';
import 'encoding_utils.dart';

/// Source of encoding detection result.
enum EncodingSource {
  bom,
  xmlDeclaration,
  htmlMeta,
  strictUtf8,
  charsetDetector,
  fallbackScore,
  manual,
}

/// Result of encoding detection.
final class EncodingDetectionResult {
  const EncodingDetectionResult({
    required this.text,
    required this.encoding,
    required this.confidence,
    required this.source,
    required this.hasReplacementChars,
  });

  final String text;
  final String encoding;
  final double confidence;
  final EncodingSource source;
  final bool hasReplacementChars;
}

/// Hybrid encoding detector using multiple signals.
///
/// Detection order:
/// 1. Forced encoding (manual override)
/// 2. BOM (UTF-8, UTF-16LE, UTF-16BE)
/// 3. XML/HTML declared encoding
/// 4. Strict UTF-8
/// 5. flutter_charset_detector (native Mozilla)
/// 6. fl_charset fallback (windows-1251, koi8-r, cp866, iso-8859-5)
/// 7. Quality scoring picks best candidate
final class BookEncodingDetector {
  /// Detect encoding and decode bytes to text.
  Future<EncodingDetectionResult> detect(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    // 1. Forced encoding (manual override from user)
    if (forcedEncoding != null && forcedEncoding.isNotEmpty) {
      final text = await _decodeByName(bytes, forcedEncoding);
      return EncodingDetectionResult(
        text: text,
        encoding: forcedEncoding,
        confidence: 1.0,
        source: EncodingSource.manual,
        hasReplacementChars: text.contains('\uFFFD'),
      );
    }

    // 2. BOM detection
    final bom = _decodeBom(bytes);
    if (bom != null) return bom;

    // 3. Declared encoding (XML declaration or HTML meta charset)
    final declared = detectDeclaredEncoding(bytes);
    if (declared != null) {
      final text = await _decodeByName(bytes, declared);
      final score = encodingQualityScore(text);
      if (declared == 'utf-8' || score > 0.50) {
        return EncodingDetectionResult(
          text: text,
          encoding: declared,
          confidence: score,
          source: declared.contains('meta')
              ? EncodingSource.htmlMeta
              : EncodingSource.xmlDeclaration,
          hasReplacementChars: text.contains('\uFFFD'),
        );
      }
    }

    // 4. Strict UTF-8
    final utf8Result = _tryStrictUtf8(bytes);
    if (utf8Result != null) return utf8Result;

    // 5. Native charset detector (Mozilla-based)
    final detected = await _tryNativeDetector(bytes);
    if (detected != null && detected.confidence >= 0.70) {
      return detected;
    }

    // 6. Fallback: try Russian encodings and pick best by quality score
    return _bestFallback(bytes);
  }

  EncodingDetectionResult? _decodeBom(Uint8List bytes) {
    if (startsWith(bytes, [0xEF, 0xBB, 0xBF])) {
      final text = utf8.decode(bytes.sublist(3), allowMalformed: false);
      return EncodingDetectionResult(
        text: text,
        encoding: 'utf-8',
        confidence: 1.0,
        source: EncodingSource.bom,
        hasReplacementChars: false,
      );
    }
    if (startsWith(bytes, [0xFF, 0xFE])) {
      final text = decodeUtf16Le(bytes.sublist(2));
      return EncodingDetectionResult(
        text: text,
        encoding: 'utf-16le',
        confidence: 1.0,
        source: EncodingSource.bom,
        hasReplacementChars: text.contains('\uFFFD'),
      );
    }
    if (startsWith(bytes, [0xFE, 0xFF])) {
      final text = decodeUtf16Be(bytes.sublist(2));
      return EncodingDetectionResult(
        text: text,
        encoding: 'utf-16be',
        confidence: 1.0,
        source: EncodingSource.bom,
        hasReplacementChars: text.contains('\uFFFD'),
      );
    }
    return null;
  }

  EncodingDetectionResult? _tryStrictUtf8(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      final score = encodingQualityScore(text);
      if (score > 0.80) {
        return EncodingDetectionResult(
          text: text,
          encoding: 'utf-8',
          confidence: score,
          source: EncodingSource.strictUtf8,
          hasReplacementChars: false,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<EncodingDetectionResult?> _tryNativeDetector(
    Uint8List bytes,
  ) async {
    try {
      final decoded = await CharsetDetector.autoDecode(bytes);
      final text = decoded.string;
      final encoding = normalizeEncodingName(decoded.charset);
      final score = encodingQualityScore(text);
      return EncodingDetectionResult(
        text: text,
        encoding: encoding,
        confidence: score,
        source: EncodingSource.charsetDetector,
        hasReplacementChars: text.contains('\uFFFD'),
      );
    } on Object catch (_) {
      return null;
    }
  }

  Future<EncodingDetectionResult> _bestFallback(Uint8List bytes) async {
    final encodings = [
      'windows-1251',
      'koi8-r',
      'ibm866',
      'iso-8859-5',
      'utf-8',
    ];

    final results = <EncodingDetectionResult>[];

    for (final encoding in encodings) {
      try {
        final text = encoding == 'utf-8'
            ? utf8.decode(bytes, allowMalformed: true)
            : await _decodeByName(bytes, encoding);
        results.add(
          EncodingDetectionResult(
            text: text,
            encoding: encoding,
            confidence: encodingQualityScore(text),
            source: EncodingSource.fallbackScore,
            hasReplacementChars: text.contains('\uFFFD'),
          ),
        );
      } on Object catch (_) {
        // ignore bad candidate
      }
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (results.isEmpty) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return EncodingDetectionResult(
        text: text,
        encoding: 'utf-8-malformed',
        confidence: 0.1,
        source: EncodingSource.fallbackScore,
        hasReplacementChars: true,
      );
    }

    return results.first;
  }

  Future<String> _decodeByName(Uint8List bytes, String encoding) async {
    final normalized = normalizeEncodingName(encoding);
    switch (normalized) {
      case 'utf-8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'utf-16le':
        return decodeUtf16Le(bytes);
      case 'utf-16be':
        return decodeUtf16Be(bytes);
      case 'iso-8859-1':
        return latin1.decode(bytes, allowInvalid: true);
      default:
        // Use fl_charset for windows-1251, koi8-r, cp866, iso-8859-5, etc.
        final enc = Charset.getByName(normalized);
        if (enc != null) {
          return enc.decode(bytes);
        }
        // Last resort: native detector
        try {
          final decoded = await CharsetDetector.autoDecode(bytes);
          return decoded.string;
        } on Object catch (_) {
          return utf8.decode(bytes, allowMalformed: true);
        }
    }
  }
}
