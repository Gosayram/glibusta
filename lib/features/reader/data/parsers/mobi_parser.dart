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
      final textExtractor = MobiTextExtractor();
      final blocks = textExtractor.extractBlocks(
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
      final chapters = MobiChapterSplitter().split(blocks);

      final coverExtractor = MobiCoverExtractor();
      final coverBytes = coverExtractor.extract(
        fullBytes: bytes,
        palmDb: palmDb,
        header: header,
        metadata: metadata,
      );

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
          'mobiCoverBytes': ?coverBytes,
          if (metadata.coverRecordIndex != null) 'mobiCoverRecordIndex': metadata.coverRecordIndex,
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

  MobiInspectResult inspectBytes(Uint8List bytes, {String? fileName}) {
    if (bytes.length < 86) {
      return const MobiInspectResult(supported: false, reason: 'Файл слишком мал');
    }
    try {
      final palmDb = PalmDbParser().parse(bytes);
      final record0 = _recordBytes(bytes, palmDb, 0);
      final header = MobiHeaderParser().parse(record0);
      final metadata = ExthParser().parse(record0, header);
      final kf8 = isLikelyKf8(header, record0);
      final compressionName = switch (header.compression) {
        1 => 'none',
        2 => 'PalmDOC',
        17480 => 'Huff/CDIC (неподдерживается)',
        _ => 'неизвестный (${header.compression})',
      };
      final readable = header.compression == 1 || header.compression == 2;
      final warning = kf8
          ? 'Файл может быть AZW3/KF8 — текст может отличаться от оригинала'
          : (!readable ? 'Сжатие Huff/CDIC не поддерживается' : null);

      return MobiInspectResult(
        supported: readable,
        title: _firstNonEmpty([
          metadata.title,
          _fullName(record0, header),
          palmDb.name,
          _stripExtension(fileName),
        ]),
        author: _splitAuthors(metadata.author).join(', '),
        compression: compressionName,
        recordCount: palmDb.records.length,
        textRecordCount: header.textRecordCount,
        exthPresent: metadata.hasExth,
        firstImageRecordIndex: header.firstImageRecordIndex,
        kf8Likely: kf8,
        reason: warning,
      );
    } on Object catch (e) {
      return MobiInspectResult(supported: false, reason: 'Ошибка чтения: $e');
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
    required this.textEncoding,
    required this.textRecordCount,
    required this.recordSize,
    required this.fullNameOffset,
    required this.fullNameLength,
    required this.exthFlags,
    required this.firstImageRecordIndex,
  });

  final int compression;
  final int textEncoding;
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
      textEncoding: reader.u16be(mobiOffset + 12),
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

final class MobiHtmlParser {
  static final _tagRe = RegExp(r'<[^>]*>');
  static final _tagNameRe = RegExp(r'^<?/?([a-zA-Z][a-zA-Z0-9]*)');
  static final _entityRe = RegExp(r'&(amp|lt|gt|nbsp|quot|apos|#\d+|#x[0-9a-fA-F]+);');
  static final _wsRe = RegExp(r'[ \t]+');

  List<ReaderBlock> parse(String html) {
    final clean = html
        .replaceAll(RegExp(r'<mbp:[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<\?[\s\S]*?\?>'), '');

    final blockChunks = _splitIntoBlockChunks(clean);
    final blocks = <ReaderBlock>[];
    var idx = 0;

    for (final chunk in blockChunks) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      if (_isHeading(lower)) {
        final text = _extractTextFromChunk(trimmed);
        if (text.isNotEmpty) {
          blocks.add(
            ReaderBlock(
              index: idx++,
              text: text,
              type: BlockType.heading,
              richSpans: _parseInline(trimmed),
            ),
          );
        }
      } else if (lower.startsWith('<hr') || lower.startsWith('<hr/>') || lower == '<hr>') {
        blocks.add(ReaderBlock(index: idx++, text: '', type: BlockType.separator));
      } else if (_isBlockquote(lower)) {
        final text = _extractTextFromChunk(trimmed);
        if (text.isNotEmpty) {
          blocks.add(
            ReaderBlock(
              index: idx++,
              text: text,
              type: BlockType.quote,
              richSpans: _parseInline(trimmed),
            ),
          );
        }
      } else {
        final inner = _stripOuterBlockTag(trimmed);
        final spans = _parseInline(inner);
        final text = _spansToText(spans);
        if (text.isNotEmpty) {
          blocks.add(ReaderBlock(index: idx++, text: text, richSpans: spans));
        }
      }
    }

    if (blocks.isEmpty) {
      final plainText = _decodeEntities(html.replaceAll(_tagRe, ' ').replaceAll(_wsRe, ' ').trim());
      if (plainText.isNotEmpty) {
        blocks.add(ReaderBlock(index: 0, text: plainText));
      }
    }
    return blocks;
  }

  List<String> _splitIntoBlockChunks(String html) {
    final result = <String>[];
    final buf = StringBuffer();
    var i = 0;

    while (i < html.length) {
      if (html[i] == '<') {
        final tagEnd = html.indexOf('>', i);
        if (tagEnd == -1) {
          buf.write(html.substring(i));
          i = html.length;
          continue;
        }
        final tag = html.substring(i, tagEnd + 1);
        final lower = tag.toLowerCase();
        final nameMatch = _tagNameRe.firstMatch(lower);
        final name = nameMatch != null ? nameMatch.group(1) : '';
        final isClosing = tag.length > 1 && tag[1] == '/';
        final isSelfClosing = tag.endsWith('/>') || _voidElements.contains(name);

        if (!isClosing && !isSelfClosing && _blockElements.contains(name)) {
          if (buf.isNotEmpty) {
            final s = buf.toString().trim();
            if (s.isNotEmpty) result.add(s);
            buf.clear();
          }
          buf.write(tag);
          i = tagEnd + 1;
          final remaining = html.substring(i).toLowerCase();
          final closeTag = '</$name>';
          final closeIdx = remaining.indexOf(closeTag);
          if (closeIdx >= 0) {
            buf.write(html.substring(i, i + closeIdx));
            i = i + closeIdx + closeTag.length;
          }
          final s = buf.toString().trim();
          if (s.isNotEmpty) result.add(s);
          buf.clear();
        } else if (name == 'br' || name == 'br/') {
          buf.write('\n');
          i = tagEnd + 1;
        } else if (name == 'p' && !isClosing) {
          if (buf.isNotEmpty) {
            final s = buf.toString().trim();
            if (s.isNotEmpty) result.add(s);
            buf.clear();
          }
          buf.write(html.substring(i, tagEnd + 1));
          i = tagEnd + 1;
          final remaining = html.substring(i).toLowerCase();
          final closeIdx = remaining.indexOf('</p>');
          if (closeIdx >= 0) {
            buf.write(html.substring(i, i + closeIdx));
            i = i + closeIdx + 4;
          }
          final s = buf.toString().trim();
          if (s.isNotEmpty) result.add(s);
          buf.clear();
        } else if (name == 'div' && !isClosing) {
          if (buf.isNotEmpty) {
            final s = buf.toString().trim();
            if (s.isNotEmpty) result.add(s);
            buf.clear();
          }
          final remaining = html.substring(i).toLowerCase();
          final closeIdx = remaining.indexOf('</div>');
          if (closeIdx >= 0) {
            result.addAll(_splitIntoBlockChunks(html.substring(i, i + closeIdx)));
            i = i + closeIdx + 6;
          } else {
            buf.write(tag);
            i = tagEnd + 1;
          }
        } else {
          buf.write(tag);
          i = tagEnd + 1;
        }
      } else {
        var nextTag = html.indexOf('<', i);
        if (nextTag == -1) nextTag = html.length;
        buf.write(html.substring(i, nextTag));
        i = nextTag;
      }
    }

    final remaining = buf.toString().trim();
    if (remaining.isNotEmpty) result.add(remaining);
    return result;
  }

  bool _isHeading(String lower) {
    return RegExp(r'^<h[1-6]').firstMatch(lower) != null;
  }

  bool _isBlockquote(String lower) => lower.startsWith('<blockquote');

  List<RichSpan> _parseInline(String chunk) {
    final spans = <RichSpan>[];
    final buf = StringBuffer();
    var bold = false;
    var italic = false;
    var superscript = false;
    String? href;
    var i = 0;

    while (i < chunk.length) {
      if (chunk[i] == '<') {
        final tagEnd = chunk.indexOf('>', i);
        if (tagEnd == -1) {
          buf.write(chunk.substring(i));
          i = chunk.length;
          continue;
        }
        final tag = chunk.substring(i, tagEnd + 1);
        final lower = tag.toLowerCase();
        final nameMatch = _tagNameRe.firstMatch(lower);
        final name = nameMatch != null ? nameMatch.group(1) : '';
        final isClosing = tag.length > 1 && tag[1] == '/';
        final isSelfClosing = tag.endsWith('/>') || _voidElements.contains(name);

        if (!isClosing && !isSelfClosing && _blockElements.contains(name)) {
          if (buf.isNotEmpty) {
            final t = _decodeEntities(buf.toString().replaceAll(_wsRe, ' ').trim());
            if (t.isNotEmpty) {
              spans.add(
                RichSpan(text: t, bold: bold, italic: italic, superscript: superscript, href: href),
              );
            }
            buf.clear();
          }
          i = tagEnd + 1;
          continue;
        }

        if (!isClosing && !isSelfClosing) {
          if (buf.isNotEmpty) {
            final t = _decodeEntities(buf.toString().replaceAll(_wsRe, ' ').trim());
            if (t.isNotEmpty) {
              spans.add(
                RichSpan(text: t, bold: bold, italic: italic, superscript: superscript, href: href),
              );
            }
            buf.clear();
          }
          if (name == 'b' || name == 'strong') {
            bold = true;
          } else if (name == 'i' || name == 'em') {
            italic = true;
          } else if (name == 'sup') {
            superscript = true;
          } else if (name == 'a') {
            final hrefMatch = RegExp(r'href="([^"]*)"').firstMatch(lower);
            if (hrefMatch != null) href = hrefMatch.group(1);
          }
          i = tagEnd + 1;
          continue;
        }

        if (isClosing) {
          if (buf.isNotEmpty) {
            final t = _decodeEntities(buf.toString().replaceAll(_wsRe, ' ').trim());
            if (t.isNotEmpty) {
              spans.add(
                RichSpan(text: t, bold: bold, italic: italic, superscript: superscript, href: href),
              );
            }
            buf.clear();
          }
          if (name == 'b' || name == 'strong') {
            bold = false;
          } else if (name == 'i' || name == 'em') {
            italic = false;
          } else if (name == 'sup') {
            superscript = false;
          } else if (name == 'a') {
            href = null;
          }
          i = tagEnd + 1;
          continue;
        }

        if (name == 'br' || name == 'br/') {
          if (buf.isNotEmpty) {
            final t = _decodeEntities(buf.toString().replaceAll(_wsRe, ' ').trim());
            if (t.isNotEmpty) {
              spans.add(
                RichSpan(text: t, bold: bold, italic: italic, superscript: superscript, href: href),
              );
            }
            buf.clear();
          }
          spans.add(
            RichSpan(text: '\n', bold: bold, italic: italic, superscript: superscript, href: href),
          );
          i = tagEnd + 1;
          continue;
        }

        buf.write(tag);
        i = tagEnd + 1;
      } else {
        var nextTag = chunk.indexOf('<', i);
        if (nextTag == -1) nextTag = chunk.length;
        buf.write(chunk.substring(i, nextTag));
        i = nextTag;
      }
    }

    if (buf.isNotEmpty) {
      final t = _decodeEntities(buf.toString().replaceAll(_wsRe, ' ').trim());
      if (t.isNotEmpty) {
        spans.add(
          RichSpan(text: t, bold: bold, italic: italic, superscript: superscript, href: href),
        );
      }
    }
    return spans;
  }

  String _extractTextFromChunk(String chunk) {
    final plain = chunk.replaceAll(_tagRe, ' ').replaceAll(_wsRe, ' ').trim();
    return _decodeEntities(plain);
  }

  String _stripOuterBlockTag(String chunk) {
    final match = RegExp(
      r'^<(p|div|blockquote|pre|section|article)[^>]*>',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (match == null) return chunk;
    final afterOpen = chunk.substring(match.end);
    final closeTag = '</${match.group(1)}>';
    final closeIdx = afterOpen.toLowerCase().lastIndexOf(closeTag);
    if (closeIdx >= 0) {
      return afterOpen.substring(0, closeIdx);
    }
    return afterOpen;
  }

  String _spansToText(List<RichSpan> spans) {
    final buf = StringBuffer();
    for (final span in spans) {
      buf.write(span.text);
    }
    return buf.toString().trim();
  }

  String _decodeEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(_entityRe, (m) {
          final entity = m.group(1)!;
          if (entity.startsWith('#')) {
            if (entity.startsWith('#x')) {
              final code = int.tryParse(entity.substring(2), radix: 16);
              return code != null ? String.fromCharCode(code) : m.group(0)!;
            }
            final code = int.tryParse(entity.substring(1));
            return code != null ? String.fromCharCode(code) : m.group(0)!;
          }
          return _entityMap[entity] ?? m.group(0)!;
        });
  }

  static const _blockElements = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'table',
    'ul',
    'ol',
    'li',
    'tr',
    'td',
    'th',
    'section',
    'article',
    'header',
    'footer',
    'figure',
    'figcaption',
  };

  static const _voidElements = {
    'br',
    'hr',
    'img',
    'input',
    'meta',
    'link',
    'area',
    'base',
    'col',
    'embed',
    'source',
    'track',
    'wbr',
  };

  static const _entityMap = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'nbsp': ' ',
    'quot': '"',
    'apos': "'",
  };
}

final class MobiChapterSplitter {
  static final _chapterPatternRe = RegExp(
    r'(?:^|\n)\s*(?:'
    r'(?:глава|часть|раздел|пролог|эпилог|предисловие|послесловие)\s*[\d]*'
    r'|(?:chapter|part|section|prologue|epilogue|preface|afterword)\s*[\d]*'
    r')\s*(?:\n|$)',
    caseSensitive: false,
  );

  List<ReaderChapter> split(List<ReaderBlock> blocks) {
    if (blocks.isEmpty) {
      return const [
        ReaderChapter(
          index: 0,
          title: 'Документ',
          blocks: [ReaderBlock(index: 0, text: 'Не удалось извлечь текст.')],
        ),
      ];
    }

    final chunks = _splitBlocksIntoChunks(blocks);
    if (chunks.length <= 1) {
      return [
        ReaderChapter(
          index: 0,
          title: chunks.isNotEmpty ? chunks[0].title : 'Документ',
          blocks: blocks,
        ),
      ];
    }

    return chunks
        .asMap()
        .entries
        .map(
          (entry) => ReaderChapter(
            index: entry.key,
            title: entry.value.title,
            blocks: entry.value.blocks,
          ),
        )
        .toList();
  }

  List<_ChapterChunk> _splitBlocksIntoChunks(List<ReaderBlock> blocks) {
    final breaks = <int>[];
    final titles = <int, String>{};

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type == BlockType.heading) {
        breaks.add(i);
        titles[i] = block.text;
      } else if (block.type == BlockType.separator && i > 0 && i < blocks.length - 1) {
        if (!_isNearbyHeading(blocks, i)) {
          breaks.add(i);
        }
      } else if (block.type == BlockType.paragraph) {
        final text = block.text;
        final match = _chapterPatternRe.firstMatch('\n$text\n');
        if (match != null) {
          breaks.add(i);
          titles[i] = text;
        }
      }
    }

    if (breaks.isEmpty) {
      return _chunkBySize(blocks);
    }

    if (breaks.first != 0) {
      breaks.insert(0, 0);
      titles[0] = 'Документ';
    }

    if (breaks.length == 1) {
      final title = titles[breaks[0]] ?? 'Документ';
      return [_ChapterChunk(title: _cleanTitle(title), blocks: blocks)];
    }

    final chunks = <_ChapterChunk>[];
    for (var b = 0; b < breaks.length; b++) {
      final start = breaks[b];
      final end = b + 1 < breaks.length ? breaks[b + 1] : blocks.length;
      final chapterBlocks = blocks.sublist(start, end).where((bl) {
        if (bl.type == BlockType.separator && breaks.contains(bl.index)) return false;
        return true;
      }).toList();
      if (chapterBlocks.isEmpty) continue;

      final title = titles[breaks[b]] ?? 'Часть ${chunks.length + 1}';
      chunks.add(_ChapterChunk(title: _cleanTitle(title), blocks: chapterBlocks));
    }

    return chunks;
  }

  bool _isNearbyHeading(List<ReaderBlock> blocks, int index) {
    for (var j = index - 2; j <= index + 2; j++) {
      if (j >= 0 && j < blocks.length && blocks[j].type == BlockType.heading) return true;
    }
    return false;
  }

  List<_ChapterChunk> _chunkBySize(List<ReaderBlock> blocks) {
    const chunkSize = 80;
    final chunks = <_ChapterChunk>[];
    for (var start = 0; start < blocks.length; start += chunkSize) {
      final end = (start + chunkSize < blocks.length) ? start + chunkSize : blocks.length;
      chunks.add(
        _ChapterChunk(
          title: 'Часть ${chunks.length + 1}',
          blocks: blocks.sublist(start, end),
        ),
      );
    }
    return chunks;
  }

  String _cleanTitle(String raw) {
    var title = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (title.length > 80) title = '${title.substring(0, 80)}…';
    return title.isNotEmpty ? title : 'Без названия';
  }
}

class _ChapterChunk {
  const _ChapterChunk({required this.title, required this.blocks});
  final String title;
  final List<ReaderBlock> blocks;
}

final class MobiCoverExtractor {
  static const _jpegStart = [0xFF, 0xD8];
  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47];
  static const _gifSignature = [0x47, 0x49, 0x46];

  Uint8List? extract({
    required Uint8List fullBytes,
    required PalmDb palmDb,
    required MobiHeader header,
    required MobiMetadata metadata,
  }) {
    final recordIndex = _findCoverRecordIndex(header, metadata);
    if (recordIndex == null || recordIndex < 0 || recordIndex >= palmDb.records.length) return null;

    final bytes = _safeRecordBytes(fullBytes, palmDb, recordIndex);
    if (bytes == null || bytes.length < 8) return null;

    return _validateImageBytes(bytes);
  }

  int? _findCoverRecordIndex(MobiHeader header, MobiMetadata metadata) {
    if (metadata.coverRecordIndex != null && metadata.coverRecordIndex! > 0) {
      return metadata.coverRecordIndex;
    }
    if (header.firstImageRecordIndex > 0) return header.firstImageRecordIndex;
    return null;
  }

  Uint8List? _safeRecordBytes(Uint8List fullBytes, PalmDb palmDb, int index) {
    if (index < 0 || index >= palmDb.records.length) return null;
    final start = palmDb.records[index].offset;
    final end = index + 1 < palmDb.records.length
        ? palmDb.records[index + 1].offset
        : fullBytes.length;
    if (start >= end || end > fullBytes.length) return null;
    return Uint8List.sublistView(fullBytes, start, end);
  }

  Uint8List? _validateImageBytes(Uint8List bytes) {
    if (_isJpeg(bytes)) return bytes;
    if (_isPng(bytes)) return bytes;
    if (_isGif(bytes)) return bytes;
    return null;
  }

  bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == _jpegStart[0] && bytes[1] == _jpegStart[1];

  bool _isPng(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == _pngSignature[0] &&
      bytes[1] == _pngSignature[1] &&
      bytes[2] == _pngSignature[2] &&
      bytes[3] == _pngSignature[3];

  bool _isGif(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == _gifSignature[0] &&
      bytes[1] == _gifSignature[1] &&
      bytes[2] == _gifSignature[2];
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

    return _decodeText(Uint8List.fromList(chunks), header.textEncoding);
  }

  List<ReaderBlock> extractBlocks({
    required Uint8List fullBytes,
    required PalmDb palmDb,
    required MobiHeader header,
  }) {
    final text = extractText(
      fullBytes: fullBytes,
      palmDb: palmDb,
      header: header,
    );
    if (_looksLikeHtml(text)) {
      return MobiHtmlParser().parse(text);
    }
    return _plainTextToBlocks(text);
  }

  bool _looksLikeHtml(String text) {
    final sample = text.length > 2000 ? text.substring(0, 2000) : text;
    return sample.contains('<p') ||
        sample.contains('<h') ||
        sample.contains('<br') ||
        sample.contains('<div') ||
        sample.contains('<b>') ||
        sample.contains('<i>');
  }

  List<ReaderBlock> _plainTextToBlocks(String text) {
    final blocks = <ReaderBlock>[];
    var idx = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      blocks.add(ReaderBlock(index: idx++, text: trimmed));
    }
    if (blocks.isEmpty && text.trim().isNotEmpty) {
      blocks.add(ReaderBlock(index: 0, text: text.trim()));
    }
    return blocks;
  }

  String _decodeText(Uint8List bytes, int textEncoding) {
    // textEncoding values: 1252 = Windows-1252, 65001 = UTF-8, 65002 = UTF-16
    if (textEncoding == 65001) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    if (textEncoding == 65002) {
      return _decodeUtf16(bytes);
    }
    if (textEncoding == 1252) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    // Fallback: try UTF-8, fall back to latin1 if too many replacement chars.
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    final replacementCount = '\uFFFD'.allMatches(utf8Text).length;
    if (replacementCount < bytes.length * 0.02) return utf8Text;
    return latin1.decode(bytes, allowInvalid: true);
  }

  String _decodeUtf16(Uint8List bytes) {
    // Detect BOM to determine endianness; strip it before decoding.
    var offset = 0;
    var bigEndian = false;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      offset = 2;
      bigEndian = false;
    } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      offset = 2;
      bigEndian = true;
    }
    // No BOM — default to little-endian (most common for Windows-originated files).
    final codeUnits = <int>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      final code = bigEndian ? (bytes[i] << 8) | bytes[i + 1] : bytes[i] | (bytes[i + 1] << 8);
      codeUnits.add(code);
    }
    // String.fromCharCodes interprets the list as UTF-16 code units and
    // correctly recombines surrogate pairs.
    return String.fromCharCodes(codeUnits);
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

final class MobiInspectResult {
  const MobiInspectResult({
    required this.supported,
    this.reason,
    this.title,
    this.author,
    this.compression,
    this.recordCount = 0,
    this.textRecordCount = 0,
    this.exthPresent = false,
    this.firstImageRecordIndex = 0,
    this.kf8Likely = false,
  });

  final bool supported;
  final String? reason;
  final String? title;
  final String? author;
  final String? compression;
  final int recordCount;
  final int textRecordCount;
  final bool exthPresent;
  final int firstImageRecordIndex;
  final bool kf8Likely;
}
