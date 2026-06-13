import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

class Fb2Parser implements BookParser {
  final _detector = BookEncodingDetector();

  @override
  bool supports(BookFormat format) => format == BookFormat.fb2;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      // Detect and handle FB2.ZIP (ZIP archive containing FB2 XML)
      final xmlBytes = _extractFromZipIfNeeded(bytes);

      final result = await _detector.detect(
        xmlBytes,
        fileName: fileName,
        forcedEncoding: forcedEncoding,
      );
      final document = XmlDocument.parse(result.text);
      return _parseDocument(document);
    } on XmlException catch (e) {
      throw ParserFailure('Ошибка разбора FB2: ${e.message}');
    } on FormatException catch (e) {
      throw ParserFailure('Неверный формат FB2: ${e.message}');
    } on Object catch (e) {
      throw ParserFailure('Неожиданная ошибка при разборе FB2: $e');
    }
  }

  /// If bytes are a ZIP archive (FB2.ZIP), extract the first .fb2 file.
  Uint8List _extractFromZipIfNeeded(Uint8List bytes) {
    if (bytes.length < 4) return bytes;

    // Check ZIP magic bytes: PK\x03\x04
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        final fb2File = archive.files.cast<ArchiveFile?>().firstWhere(
          (f) => f!.name.toLowerCase().endsWith('.fb2'),
          orElse: () => null,
        );
        if (fb2File == null) {
          throw const FormatException('FB2.ZIP: .fb2 файл не найден в архиве');
        }
        return Uint8List.fromList(fb2File.content as List<int>);
      } on Object catch (_) {
        // If ZIP decoding fails, try raw bytes as plain FB2 XML
        return bytes;
      }
    }
    return bytes;
  }

  @override
  Future<NormalizedBook> parseFile(
    String filePath, {
    String? forcedEncoding,
  }) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: forcedEncoding,
      );
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл FB2: ${e.message}');
    }
  }

  NormalizedBook _parseDocument(XmlDocument document) {
    final description = _parseDescription(document);
    final body = _parseBody(document);

    return NormalizedBook(
      id: description['id'] as String? ?? 'unknown',
      title: description['title'] as String? ?? 'Unknown Title',
      authors: (description['authors'] as List<String>?) ?? [],
      description: description['annotation'] as String?,
      coverUrl: description['coverUrl'] as String?,
      chapters: body,
      metadata: {
        'publisher': description['publisher'],
        'year': description['year'],
        'language': description['language'],
        'genres': description['genres'],
      },
    );
  }

  Map<String, dynamic> _parseDescription(XmlDocument document) {
    final result = <String, dynamic>{};

    final titleInfo = document.findAllElements('title-info');
    if (titleInfo.isNotEmpty) {
      final title = titleInfo.first.findAllElements('book-title');
      if (title.isNotEmpty) {
        result['title'] = title.first.innerText;
      }

      final authors = <String>[];
      for (final author in titleInfo.first.findAllElements('author')) {
        final firstName = author.findAllElements('first-name');
        final lastName = author.findAllElements('last-name');
        if (firstName.isNotEmpty && lastName.isNotEmpty) {
          authors.add('${firstName.first.innerText} ${lastName.first.innerText}');
        }
      }
      result['authors'] = authors;

      final annotation = titleInfo.first.findAllElements('annotation');
      if (annotation.isNotEmpty) {
        result['annotation'] = annotation.first.innerText;
      }

      final genres = <String>[];
      for (final genre in titleInfo.first.findAllElements('genre')) {
        genres.add(genre.innerText);
      }
      result['genres'] = genres;
    }

    final documentInfo = document.findAllElements('document-info');
    if (documentInfo.isNotEmpty) {
      final id = documentInfo.first.findAllElements('id');
      if (id.isNotEmpty) {
        result['id'] = id.first.innerText;
      }
    }

    return result;
  }

  List<ReaderChapter> _parseBody(XmlDocument document) {
    final chapters = <ReaderChapter>[];
    int chapterIndex = 0;

    final bodies = document.findAllElements('body');
    for (final body in bodies) {
      final blocks = _parseSection(body, chapterIndex);
      if (blocks.isNotEmpty) {
        chapters.add(
          ReaderChapter(
            index: chapterIndex++,
            title: 'Chapter $chapterIndex',
            blocks: blocks,
          ),
        );
      }
    }

    return chapters;
  }

  List<ReaderBlock> _parseSection(XmlElement element, int chapterIndex) {
    final blocks = <ReaderBlock>[];
    int blockIndex = 0;

    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'p':
          final text = child.innerText.trim();
          if (text.isNotEmpty) {
            blocks.add(
              ReaderBlock(
                index: blockIndex++,
                text: text,
              ),
            );
          }
          break;
        case 'subtitle':
          final text = child.innerText.trim();
          if (text.isNotEmpty) {
            blocks.add(
              ReaderBlock(
                index: blockIndex++,
                text: text,
                type: BlockType.heading,
              ),
            );
          }
          break;
        case 'image':
          final href =
              child.getAttribute('l:href') ??
              child.getAttribute('href') ??
              child.getAttribute('xlink:href');
          if (href != null) {
            blocks.add(
              ReaderBlock(
                index: blockIndex++,
                text: '',
                type: BlockType.image,
                imageUrl: href,
              ),
            );
          }
          break;
        case 'cite':
          final text = child.innerText.trim();
          if (text.isNotEmpty) {
            blocks.add(
              ReaderBlock(
                index: blockIndex++,
                text: text,
                type: BlockType.quote,
              ),
            );
          }
          break;
        case 'section':
          blocks.addAll(_parseSection(child, chapterIndex));
          break;
      }
    }

    return blocks;
  }
}
