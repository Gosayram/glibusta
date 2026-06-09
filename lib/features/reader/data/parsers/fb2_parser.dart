import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'book_parser.dart';
import 'normalized_book.dart';

class Fb2Parser implements BookParser {
  @override
  Future<NormalizedBook> parse(Uint8List bytes, {String? fileName}) async {
    final document = XmlDocument.parse(String.fromCharCodes(bytes));
    return _parseDocument(document);
  }

  @override
  Future<NormalizedBook> parseFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return parse(bytes, fileName: filePath.split('/').last);
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
          final href = child.getAttribute('l:href');
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
