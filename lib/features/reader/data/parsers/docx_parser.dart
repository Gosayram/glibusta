import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../../../core/errors/failures.dart';
import 'book_parser.dart';
import 'format_detector.dart';
import 'normalized_book.dart';

final class DocxParser implements BookParser {
  @override
  bool supports(BookFormat format) => format == BookFormat.docx;

  @override
  Future<NormalizedBook> parse(
    Uint8List bytes, {
    String? fileName,
    String? forcedEncoding,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = _findFile(archive, 'word/document.xml');
      if (documentXml == null) {
        throw const ParserFailure('word/document.xml не найден в DOCX');
      }
      final content = String.fromCharCodes(documentXml);
      final doc = XmlDocument.parse(content);
      final title = _extractTitle(archive) ?? _titleFromFileName(fileName);
      final blocks = _extractBlocks(doc);
      return NormalizedBook(
        id: fileName ?? 'unknown.docx',
        title: title,
        authors: _extractAuthors(archive),
        chapters: [
          ReaderChapter(index: 0, title: 'Текст', blocks: blocks),
        ],
      );
    } on ParserFailure {
      rethrow;
    } on Object catch (e) {
      throw ParserFailure('Ошибка разбора DOCX: $e');
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
      final name = filePath.split('/').last;
      return parse(bytes, fileName: name, forcedEncoding: forcedEncoding);
    } on ParserFailure {
      rethrow;
    } on FileSystemException catch (e) {
      throw ParserFailure('Не удалось прочитать файл DOCX: ${e.message}');
    }
  }

  Uint8List? _findFile(Archive archive, String path) {
    for (final file in archive) {
      if (file.name == path) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    return null;
  }

  String? _extractTitle(Archive archive) {
    final coreProps = _findFile(archive, 'docProps/core.xml');
    if (coreProps != null) {
      try {
        final propsDoc = XmlDocument.parse(String.fromCharCodes(coreProps));
        final titleEl = propsDoc.findAllElements(
          'dc:title',
          namespaceUri: 'http://purl.org/dc/elements/1.1/',
        );
        if (titleEl.isNotEmpty) {
          final text = titleEl.first.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      } on Object catch (_) {}
    }
    final appProps = _findFile(archive, 'docProps/app.xml');
    if (appProps != null) {
      try {
        final propsDoc = XmlDocument.parse(String.fromCharCodes(appProps));
        final titleEl = propsDoc.findAllElements('Title');
        if (titleEl.isNotEmpty) {
          final text = titleEl.first.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      } on Object catch (_) {}
    }
    return null;
  }

  List<String> _extractAuthors(Archive archive) {
    final coreProps = _findFile(archive, 'docProps/core.xml');
    if (coreProps != null) {
      try {
        final propsDoc = XmlDocument.parse(String.fromCharCodes(coreProps));
        final authorEls = propsDoc.findAllElements(
          'dc:creator',
          namespaceUri: 'http://purl.org/dc/elements/1.1/',
        );
        return authorEls.map((e) => e.innerText.trim()).where((e) => e.isNotEmpty).toList();
      } on Object catch (_) {}
    }
    return const [];
  }

  String _titleFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'Без названия';
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  List<ReaderBlock> _extractBlocks(XmlDocument doc) {
    final blocks = <ReaderBlock>[];
    var index = 0;
    final body = doc.findAllElements('w:body');
    if (body.isEmpty) return blocks;
    for (final paragraph in body.first.findAllElements('w:p')) {
      final runs = <RichSpan>[];
      var text = '';
      for (final run in paragraph.findAllElements('w:r')) {
        final textEl = run.findAllElements('w:t');
        final runText = textEl.map((e) => e.innerText).join();
        if (runText.isNotEmpty) {
          final rPr = run.findAllElements('w:rPr').firstOrNull;
          final bold = rPr?.findAllElements('w:b').isNotEmpty ?? false;
          final italic = rPr?.findAllElements('w:i').isNotEmpty ?? false;
          runs.add(RichSpan(text: runText, bold: bold, italic: italic));
          text += runText;
        }
      }
      if (text.trim().isEmpty) continue;
      final pPr = paragraph.findAllElements('w:pPr').firstOrNull;
      final outlineLevel = pPr?.findAllElements('w:outlineLvl').firstOrNull;
      final isHeading = outlineLevel != null;
      blocks.add(
        ReaderBlock(
          index: index++,
          text: text.trim(),
          type: isHeading ? BlockType.heading : BlockType.paragraph,
          richSpans: runs.isNotEmpty ? runs : null,
        ),
      );
    }
    return blocks;
  }
}
