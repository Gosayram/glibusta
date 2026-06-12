import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../../../core/encoding/encoding_detection.dart';
import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

class EpubParser implements BookParser {
  final _detector = BookEncodingDetector();

  @override
  bool supports(BookFormat format) => format == BookFormat.epub;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      return _parseArchive(archive, forcedEncoding: forcedEncoding);
    } on Object catch (e) {
      throw ParserFailure('Ошибка при разборе EPUB: $e');
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
      return parse(
        bytes,
        fileName: filePath.split('/').last,
        forcedEncoding: forcedEncoding,
      );
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл EPUB: ${e.message}');
    }
  }

  Future<NormalizedBook> _parseArchive(
    Archive archive, {
    String? forcedEncoding,
  }) async {
    final fileIndex = <String, ArchiveFile>{};
    for (final file in archive) {
      if (file.isFile) {
        fileIndex[file.name] = file;
        final decoded = Uri.decodeComponent(file.name);
        if (decoded != file.name) {
          fileIndex[decoded] = file;
        }
      }
    }

    final containerBytes = _findFileBytesFromIndex(fileIndex, 'META-INF/container.xml');
    if (containerBytes == null) {
      throw const ParserFailure('EPUB: container.xml не найден');
    }
    final containerResult = await _detector.detect(
      Uint8List.fromList(containerBytes),
      forcedEncoding: forcedEncoding,
    );

    final opfPath = _parseContainerPath(containerResult.text);
    if (opfPath == null) {
      throw const ParserFailure('EPUB: путь к OPF не найден');
    }

    final opfBytes = _findFileBytesFromIndex(fileIndex, opfPath);
    if (opfBytes == null) {
      throw ParserFailure('EPUB: OPF файл не найден: $opfPath');
    }
    final opfResult = await _detector.detect(
      Uint8List.fromList(opfBytes),
      forcedEncoding: forcedEncoding,
    );

    final opfBase = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
    final opfDoc = XmlDocument.parse(opfResult.text);

    final metadata = _parseMetadata(opfDoc);
    final manifest = _parseManifest(opfDoc, opfBase);
    final spineOrder = _parseSpine(opfDoc);

    final chapters = <ReaderChapter>[];
    var chapterIndex = 0;
    for (final href in spineOrder) {
      final fullPath = '$opfBase$href';
      final htmlBytes =
          _findFileBytesFromIndex(fileIndex, fullPath) ?? _findFileBytesFromIndex(fileIndex, href);
      if (htmlBytes == null) continue;

      final htmlResult = await _detector.detect(
        Uint8List.fromList(htmlBytes),
        forcedEncoding: forcedEncoding,
      );

      final doc = html_parser.parse(htmlResult.text);
      final title = _extractChapterTitle(doc);
      final blocks = _htmlToBlocks(doc);

      if (blocks.isNotEmpty) {
        chapters.add(
          ReaderChapter(
            index: chapterIndex++,
            title: title ?? 'Глава $chapterIndex',
            blocks: blocks,
          ),
        );
      }
    }

    List<int>? coverBytes;
    final coverId = metadata['cover'] as String?;
    if (coverId != null) {
      final coverHref = manifest[coverId];
      if (coverHref != null) {
        final coverData =
            _findFileBytesFromIndex(fileIndex, '$opfBase$coverHref') ??
            _findFileBytesFromIndex(fileIndex, coverHref);
        if (coverData != null) {
          coverBytes = coverData;
        }
      }
    }

    return NormalizedBook(
      id: (metadata['title'] as String?) ?? 'unknown',
      title: (metadata['title'] as String?) ?? 'Unknown Title',
      authors: (metadata['authors'] as List<String>?) ?? const [],
      description: metadata['description'] as String?,
      coverUrl: coverBytes != null ? 'embedded' : null,
      chapters: chapters.isEmpty
          ? [
              const ReaderChapter(
                index: 0,
                title: 'Main Content',
                blocks: [],
              ),
            ]
          : chapters,
      metadata: {
        ...metadata,
        'hasCover': coverBytes != null,
        'totalChapters': chapters.length,
      },
    );
  }

  String? _parseContainerPath(String containerXml) {
    final doc = XmlDocument.parse(containerXml);
    final rootfiles = doc.findAllElements('rootfile');
    for (final rootfile in rootfiles) {
      final mediaType = rootfile.getAttribute('media-type');
      if (mediaType == 'application/oebps-package+xml') {
        return rootfile.getAttribute('full-path');
      }
    }
    return rootfiles.firstOrNull?.getAttribute('full-path');
  }

  Map<String, dynamic> _parseMetadata(XmlDocument opfDoc) {
    final result = <String, dynamic>{};
    final metadataEl = opfDoc.findAllElements('metadata').firstOrNull;
    if (metadataEl == null) return result;

    result['title'] = _firstChildText(metadataEl, 'dc:title');
    result['description'] = _firstChildText(metadataEl, 'dc:description');
    result['language'] = _firstChildText(metadataEl, 'dc:language');

    final authors = <String>[];
    for (final creator in metadataEl.findAllElements('dc:creator')) {
      final name = creator.innerText.trim();
      if (name.isNotEmpty) authors.add(name);
    }
    result['authors'] = authors;

    final coverMeta = metadataEl
        .findAllElements('meta')
        .where((m) => m.getAttribute('name') == 'cover')
        .toList();
    if (coverMeta.isNotEmpty) {
      result['cover'] = coverMeta.first.getAttribute('content');
    }

    return result;
  }

  Map<String, String> _parseManifest(XmlDocument opfDoc, String opfBase) {
    final result = <String, String>{};
    final manifest = opfDoc.findAllElements('manifest').firstOrNull;
    if (manifest == null) return result;

    for (final item in manifest.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        result[id] = href;
      }
    }
    return result;
  }

  List<String> _parseSpine(XmlDocument opfDoc) {
    final result = <String>[];
    final spine = opfDoc.findAllElements('spine').firstOrNull;
    if (spine == null) return result;

    for (final itemref in spine.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref') ?? '';
      if (idref.isNotEmpty) result.add(idref);
    }

    if (result.isEmpty) {
      final manifest = opfDoc.findAllElements('manifest').firstOrNull;
      if (manifest != null) {
        final spineItem = manifest
            .findAllElements('item')
            .where((i) => i.getAttribute('id') == 'ncx')
            .toList();
        if (spineItem.isNotEmpty) {
          for (final item in manifest.findAllElements('item')) {
            final mediaType = item.getAttribute('media-type');
            if (mediaType == 'application/xhtml+xml') {
              final href = item.getAttribute('href');
              if (href != null) result.add(href);
            }
          }
        }
      }
    }

    return result;
  }

  String? _extractChapterTitle(dom.Document doc) {
    final titleEl = doc.querySelector('title');
    if (titleEl != null && titleEl.text.trim().isNotEmpty) {
      return titleEl.text.trim();
    }
    for (final tag in ['h1', 'h2', 'h3']) {
      final el = doc.querySelector(tag);
      if (el != null && el.text.trim().isNotEmpty) {
        return el.text.trim();
      }
    }
    return null;
  }

  List<ReaderBlock> _htmlToBlocks(dom.Document doc) {
    final nodes = doc.querySelectorAll(
      'p, h1, h2, h3, h4, h5, h6, img, blockquote, div, li',
    );
    final blocks = <ReaderBlock>[];
    for (final node in nodes) {
      if (node.localName == 'img') {
        final src = node.attributes['src'] ?? node.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          blocks.add(
            ReaderBlock(
              index: blocks.length,
              text: '',
              type: BlockType.image,
              imageUrl: src,
            ),
          );
        }
        continue;
      }
      final text = node.text.trim();
      if (text.isNotEmpty) {
        blocks.add(
          ReaderBlock(
            index: blocks.length,
            text: text,
            type: _getBlockType(node.localName),
          ),
        );
      }
    }
    return blocks;
  }

  BlockType _getBlockType(String? tagName) {
    switch (tagName) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return BlockType.heading;
      case 'img':
        return BlockType.image;
      case 'blockquote':
        return BlockType.quote;
      default:
        return BlockType.paragraph;
    }
  }

  String? _firstChildText(XmlElement parent, String tag) {
    final el = parent.findAllElements(tag).firstOrNull;
    return el?.innerText.trim();
  }

  List<int>? _findFileBytesFromIndex(Map<String, ArchiveFile> index, String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final file = index[normalized] ?? index[Uri.decodeComponent(normalized)];
    return file?.content;
  }
}
