import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

const _asciiDecoder = AsciiDecoder(allowInvalid: true);
const _maxDecompressedRecordBytes = 8 * 1024 * 1024;
const _maxTotalTextBytes = 32 * 1024 * 1024;

final class MobiBookParser implements BookParser {
  @override
  bool supports(BookFormat format) =>
      format == BookFormat.mobi || format == BookFormat.azw3 || format == BookFormat.prc;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      if (bytes.length < 86) {
        throw const FormatException('File is too small for PalmDB/MOBI');
      }

      final palmDb = PalmDbParser().parse(bytes);
      final record0 = _recordBytes(bytes, palmDb, 0);
      final header = MobiHeaderParser().parse(record0);
      final metadata = ExthParser().parse(record0, header);
      final text = MobiTextExtractor().extractText(
        fullBytes: bytes,
        palmDb: palmDb,
        header: header,
      );
      final title = _firstNonEmpty([
        metadata.title,
        _fullName(record0, header),
        palmDb.name,
        _stripExtension(fileName),
      ]);
      final authors = _splitAuthors(metadata.author);
      final format = fileName == null ? BookFormat.mobi : detectBookFormat(fileName);
      final chapters = _textToChapters(text);

      return NormalizedBook(
        id: _stableId(fileName, bytes),
        title: title,
        authors: authors.isEmpty ? const ['Unknown'] : authors,
        description: _descriptionFor(header),
        chapters: chapters,
        metadata: {
          'format': format.name,
          'mobiCompression': header.compression,
          'mobiTextRecordCount': header.textRecordCount,
          'mobiRecordCount': palmDb.records.length,
          'mobiExthPresent': metadata.hasExth,
          'mobiLanguage': metadata.language,
          'mobiFirstImageRecordIndex': header.firstImageRecordIndex,
          'mobiKf8Likely': isLikelyKf8(header, record0),
        },
      );
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора MOBI/AZW3: $e');
    }
  }

  @override
  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ParserFailure('Файл не найден: $filePath');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw ParserFailure('Файл пуст: $filePath');
      }
      return parse(bytes, fileName: filePath.split(Platform.pathSeparator).last);
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл MOBI/AZW3: ${e.message}');
    }
  }
}

final class BinaryReader {
  const BinaryReader(this.bytes);

  final Uint8List bytes;

  int u16be(int offset) {
    _check(offset, 2);
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int u32be(int offset) {
    _check(offset, 4);
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  String ascii(int offset, int length) {
    _check(offset, length);
    return _asciiDecoder.convert(bytes.sublist(offset, offset + length));
  }

  Uint8List slice(int start, int end) {
    if (start < 0 || end < start || end > bytes.length) {
      throw RangeError.range(end, start, bytes.length, 'end');
    }
    return Uint8List.sublistView(bytes, start, end);
  }

  void _check(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw RangeError.range(offset, 0, bytes.length - length, 'offset');
    }
  }
}

final class PalmRecord {
  const PalmRecord({
    required this.offset,
    required this.attributes,
    required this.uniqueId,
  });

  final int offset;
  final int attributes;
  final int uniqueId;
}

final class PalmDb {
  const PalmDb({
    required this.name,
    required this.records,
  });

  final String name;
  final List<PalmRecord> records;
}

final class PalmDbParser {
  PalmDb parse(Uint8List bytes) {
    final reader = BinaryReader(bytes);
    final recordCount = reader.u16be(76);
    final tableEnd = 78 + recordCount * 8;
    if (recordCount <= 0 || tableEnd > bytes.length) {
      throw const FormatException('Invalid PalmDB record table');
    }

    final records = <PalmRecord>[];
    var offset = 78;
    var previousRecordOffset = -1;
    for (var i = 0; i < recordCount; i++) {
      final recordOffset = reader.u32be(offset);
      if (recordOffset < tableEnd || recordOffset >= bytes.length) {
        throw FormatException('Invalid PalmDB record offset: $recordOffset');
      }
      if (previousRecordOffset > recordOffset) {
        throw const FormatException('PalmDB record offsets are not sorted');
      }
      previousRecordOffset = recordOffset;
      records.add(
        PalmRecord(
          offset: recordOffset,
          attributes: bytes[offset + 4],
          uniqueId: (bytes[offset + 5] << 16) | (bytes[offset + 6] << 8) | bytes[offset + 7],
        ),
      );
      offset += 8;
    }

    return PalmDb(
      name: reader.ascii(0, 32).replaceAll('\u0000', '').trim(),
      records: records,
    );
  }
}

final class MobiHeader {
  const MobiHeader({
    required this.compression,
    required this.textRecordCount,
    required this.recordSize,
    required this.fullNameOffset,
    required this.fullNameLength,
    required this.exthFlags,
    required this.firstImageRecordIndex,
  });

  final int compression;
  final int textRecordCount;
  final int recordSize;
  final int fullNameOffset;
  final int fullNameLength;
  final int exthFlags;
  final int firstImageRecordIndex;
}

final class MobiHeaderParser {
  MobiHeader parse(Uint8List record0) {
    final reader = BinaryReader(record0);
    const mobiOffset = 16;
    if (reader.ascii(mobiOffset, 4) != 'MOBI') {
      throw const FormatException('Invalid MOBI header');
    }

    return MobiHeader(
      compression: reader.u16be(0),
      textRecordCount: reader.u16be(8),
      recordSize: reader.u16be(10),
      fullNameOffset: reader.u32be(mobiOffset + 84),
      fullNameLength: reader.u32be(mobiOffset + 88),
      exthFlags: reader.u32be(mobiOffset + 128),
      firstImageRecordIndex: reader.u32be(mobiOffset + 108),
    );
  }
}

final class MobiMetadata {
  const MobiMetadata({
    this.title,
    this.author,
    this.language,
    this.coverRecordIndex,
    this.hasExth = false,
  });

  final String? title;
  final String? author;
  final String? language;
  final int? coverRecordIndex;
  final bool hasExth;
}

final class ExthParser {
  MobiMetadata parse(Uint8List record0, MobiHeader header) {
    if ((header.exthFlags & 0x40) == 0) return const MobiMetadata();

    final exthOffset = _findExthOffset(record0);
    if (exthOffset == -1) return const MobiMetadata();

    final reader = BinaryReader(record0);
    final length = reader.u32be(exthOffset + 4);
    final count = reader.u32be(exthOffset + 8);
    final exthEnd = exthOffset + length;
    if (length < 12 || exthEnd > record0.length) {
      return const MobiMetadata(hasExth: true);
    }

    String? title;
    String? author;
    String? language;
    int? coverRecordIndex;
    var pos = exthOffset + 12;

    for (var i = 0; i < count && pos + 8 <= exthEnd; i++) {
      final type = reader.u32be(pos);
      final size = reader.u32be(pos + 4);
      if (size < 8 || pos + size > exthEnd) break;

      final data = record0.sublist(pos + 8, pos + size);
      switch (type) {
        case 100:
          author = utf8.decode(data, allowMalformed: true).trim();
        case 503:
          title = utf8.decode(data, allowMalformed: true).trim();
        case 524:
          language = utf8.decode(data, allowMalformed: true).trim();
        case 201:
          if (data.length >= 4) {
            coverRecordIndex = BinaryReader(data).u32be(0);
          }
      }
      pos += size;
    }

    return MobiMetadata(
      title: title,
      author: author,
      language: language,
      coverRecordIndex: coverRecordIndex,
      hasExth: true,
    );
  }

  int _findExthOffset(Uint8List record0) {
    for (var i = 0; i + 4 <= record0.length; i++) {
      if (record0[i] == 0x45 &&
          record0[i + 1] == 0x58 &&
          record0[i + 2] == 0x54 &&
          record0[i + 3] == 0x48) {
        return i;
      }
    }
    return -1;
  }
}

final class PalmDocDecompressor {
  Uint8List decompress(Uint8List input) {
    final out = <int>[];
    var i = 0;

    while (i < input.length) {
      if (out.length > _maxDecompressedRecordBytes) {
        throw const FormatException('MOBI record is too large after decompression');
      }
      final c = input[i++];
      if (c == 0) {
        out.add(c);
      } else if (c <= 8) {
        for (var j = 0; j < c && i < input.length; j++) {
          out.add(input[i++]);
        }
      } else if (c <= 0x7F) {
        out.add(c);
      } else if (c <= 0xBF) {
        if (i >= input.length) break;
        final c2 = input[i++];
        final distance = ((c & 0x3F) << 5) | (c2 >> 3);
        final length = (c2 & 0x07) + 3;
        final start = out.length - distance;
        if (distance <= 0 || start < 0) {
          throw const FormatException('Invalid PalmDOC back reference');
        }
        for (var j = 0; j < length; j++) {
          out.add(out[start + j]);
        }
      } else {
        out
          ..add(0x20)
          ..add(c ^ 0x80);
      }
    }

    return Uint8List.fromList(out);
  }
}

final class MobiTextExtractor {
  String extractText({
    required Uint8List fullBytes,
    required PalmDb palmDb,
    required MobiHeader header,
  }) {
    if (header.compression != 1 && header.compression != 2) {
      throw UnsupportedError('Unsupported MOBI compression: ${header.compression}');
    }
    if (header.textRecordCount <= 0 || header.textRecordCount >= palmDb.records.length) {
      throw const FormatException('Invalid MOBI text record count');
    }

    final chunks = <int>[];
    for (var i = 1; i <= header.textRecordCount; i++) {
      final record = _recordBytes(fullBytes, palmDb, i);
      final decompressed = header.compression == 1
          ? record
          : PalmDocDecompressor().decompress(record);
      chunks.addAll(decompressed);
      if (chunks.length > _maxTotalTextBytes) {
        throw const FormatException('MOBI text stream is too large');
      }
    }

    return _cleanup(_decodeText(Uint8List.fromList(chunks)));
  }

  String _decodeText(Uint8List bytes) {
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final replacementCount = '\uFFFD'.allMatches(utf8Text).length;
    if (replacementCount < bytes.length * 0.02) return utf8Text;
    return latin1.decode(bytes, allowInvalid: true);
  }

  String _cleanup(String input) {
    return input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

bool isLikelyKf8(MobiHeader header, Uint8List record0) {
  final text = latin1.decode(record0, allowInvalid: true);
  return text.contains('BOUNDARY') || text.contains('FDST') || text.contains('RESC');
}

Uint8List _recordBytes(Uint8List bytes, PalmDb palmDb, int index) {
  if (index < 0 || index >= palmDb.records.length) {
    throw RangeError.index(index, palmDb.records, 'index');
  }
  final start = palmDb.records[index].offset;
  final end = index + 1 < palmDb.records.length ? palmDb.records[index + 1].offset : bytes.length;
  return BinaryReader(bytes).slice(start, end);
}

String? _fullName(Uint8List record0, MobiHeader header) {
  if (header.fullNameLength <= 0) return null;
  final end = header.fullNameOffset + header.fullNameLength;
  if (header.fullNameOffset < 0 || end > record0.length) return null;
  return utf8
      .decode(
        record0.sublist(header.fullNameOffset, end),
        allowMalformed: true,
      )
      .trim();
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return 'MOBI document';
}

List<String> _splitAuthors(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(RegExp(r'\s*(?:;|,|\band\b|&)\s*', caseSensitive: false))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<ReaderChapter> _textToChapters(String text) {
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (paragraphs.isEmpty) {
    return const [
      ReaderChapter(
        index: 0,
        title: 'Документ',
        blocks: [ReaderBlock(index: 0, text: 'Не удалось извлечь текст из MOBI.')],
      ),
    ];
  }

  final chapters = <ReaderChapter>[];
  const chunkSize = 80;
  for (var start = 0; start < paragraphs.length; start += chunkSize) {
    final chunk = paragraphs.skip(start).take(chunkSize).toList();
    chapters.add(
      ReaderChapter(
        index: chapters.length,
        title: chapters.isEmpty ? 'Документ' : 'Часть ${chapters.length + 1}',
        blocks: chunk
            .asMap()
            .entries
            .map((entry) => ReaderBlock(index: entry.key, text: entry.value))
            .toList(),
      ),
    );
  }
  return chapters;
}

String _stableId(String? fileName, Uint8List bytes) {
  final digest = sha1.convert(bytes.take(1024 * 1024).toList()).toString();
  final prefix = _stripExtension(fileName) ?? 'mobi';
  return '${prefix}_$digest';
}

String? _stripExtension(String? fileName) {
  if (fileName == null || fileName.isEmpty) return null;
  final normalized = fileName.split('/').last.split(Platform.pathSeparator).last;
  final dot = normalized.lastIndexOf('.');
  return dot > 0 ? normalized.substring(0, dot) : normalized;
}

String _descriptionFor(MobiHeader header) {
  if (header.compression == 17480) {
    return 'MOBI/AZW3 document: Huff/CDIC compression is not supported yet';
  }
  return 'MOBI document';
}
