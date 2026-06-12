import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'epub_archive.dart';
import 'epub_image_store.dart';
import 'epub_models.dart';
import 'epub_resource_resolver.dart';

final class EpubHtmlParser {
  EpubHtmlParser({
    required this.resolver,
    required this.imageStore,
    required this.epub,
  });

  final EpubResourceResolver resolver;
  final EpubImageStore imageStore;
  final EpubArchive epub;

  Future<List<ReaderBlock>> parseChapter({
    required String chapterPath,
    required String htmlText,
  }) async {
    final doc = html_parser.parse(htmlText);
    final body = doc.body;
    if (body == null) return const [];
    return _processChildren(body, chapterPath);
  }

  Future<List<ReaderBlock>> _processChildren(Node parent, String chapterPath) async {
    final blocks = <ReaderBlock>[];
    for (final node in parent.nodes) {
      if (node is Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          blocks.add(ParagraphBlock([TextSpan(text: text)]));
        }
      } else if (node is Element) {
        final block = await _processElement(node, chapterPath);
        if (block != null) {
          blocks.add(block);
        }
      }
    }
    return blocks;
  }

  Future<ReaderBlock?> _processElement(Element el, String chapterPath) async {
    final tag = el.localName;
    switch (tag) {
      case 'p':
        final spans = _extractInlineSpans(el, chapterPath);
        if (spans.isEmpty) return null;
        return ParagraphBlock(spans);
      case 'div':
      case 'section':
        final childBlocks = await _processChildren(el, chapterPath);
        if (childBlocks.isEmpty) return null;
        if (childBlocks.length == 1) return childBlocks.first;
        return SectionBlock(childBlocks);

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(tag![1]);
        final text = el.text.trim();
        if (text.isEmpty) return null;
        return HeadingBlock(text, level);

      case 'img':
        return _processImage(el, chapterPath);

      case 'ul':
        return _processList(el, ordered: false, chapterPath: chapterPath);
      case 'ol':
        return _processList(el, ordered: true, chapterPath: chapterPath);

      case 'table':
        return _processTable(el, chapterPath);

      case 'blockquote':
        final text = el.text.trim();
        if (text.isEmpty) return null;
        return QuoteBlock(text);

      case 'hr':
        return const SeparatorBlock();

      case 'br':
        return null;

      case 'span':
        if (_isPageBreak(el)) {
          final label = el.attributes['epub:type'] == 'pagebreak'
              ? (el.attributes['title'] ?? el.attributes['id'] ?? '')
              : (el.attributes['title'] ?? '');
          return PageBreakBlock(label: label);
        }
        final spans = _extractInlineSpans(el, chapterPath);
        if (spans.isEmpty) return null;
        return ParagraphBlock(spans);

      default:
        final childBlocks = await _processChildren(el, chapterPath);
        if (childBlocks.isEmpty) return null;
        if (childBlocks.length == 1) return childBlocks.first;
        return SectionBlock(childBlocks);
    }
  }

  List<TextSpan> _extractInlineSpans(Element el, String chapterPath) {
    final spans = <TextSpan>[];
    _walkInline(el, spans, chapterPath, bold: false, italic: false, superscript: false);
    return spans;
  }

  void _walkInline(
    Element el,
    List<TextSpan> spans,
    String chapterPath, {
    required bool bold,
    required bool italic,
    required bool superscript,
    String? href,
  }) {
    for (final node in el.nodes) {
      if (node is Text) {
        final text = node.text;
        if (text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: text,
              bold: bold,
              italic: italic,
              superscript: superscript,
              href: href,
            ),
          );
        }
      } else if (node is Element) {
        final tag = node.localName;
        var newBold = bold;
        var newItalic = italic;
        var newSuperscript = superscript;
        String? href;

        switch (tag) {
          case 'strong':
          case 'b':
            newBold = true;
            break;
          case 'em':
          case 'i':
            newItalic = true;
            break;
          case 'sup':
            newSuperscript = true;
            break;
          case 'a':
            href = node.attributes['href'];
            break;
          case 'img':
            continue;
          case 'br':
            spans.add(const TextSpan(text: '\n'));
            continue;
          default:
            break;
        }

        // If this is an <a> with a single text node, extract it directly
        if (tag == 'a' && node.nodes.length == 1 && node.nodes.first is Text) {
          final text = (node.nodes.first as Text).text;
          if (text.isNotEmpty) {
            spans.add(
              TextSpan(
                text: text,
                bold: newBold,
                italic: newItalic,
                superscript: newSuperscript,
                href: href,
              ),
            );
            continue;
          }
        }

        _walkInline(
          node,
          spans,
          chapterPath,
          bold: newBold,
          italic: newItalic,
          superscript: newSuperscript,
          href: href,
        );
      }
    }
  }

  Future<ReaderBlock?> _processImage(Element el, String chapterPath) async {
    final src = el.attributes['src'];
    if (src == null || src.isEmpty) return null;
    final resource = resolver.resolveFromHref(chapterPath: chapterPath, href: src);
    if (resource == null) return null;
    final localPath = await imageStore.saveImage(epub: epub, resource: resource);
    return ImageBlock(
      resourceId: resource.id,
      localPath: localPath,
      alt: el.attributes['alt'],
    );
  }

  Future<ListBlock> _processList(
    Element el, {
    required bool ordered,
    required String chapterPath,
  }) async {
    final items = <String>[];
    for (final child in el.children) {
      if (child.localName == 'li') {
        final text = child.text.trim();
        if (text.isNotEmpty) items.add(text);
      }
    }
    return ListBlock(ordered: ordered, items: items);
  }

  Future<TableBlock> _processTable(Element el, String chapterPath) async {
    final rows = <List<String>>[];
    for (final tr in el.querySelectorAll('tr')) {
      final cells = <String>[];
      for (final cell in tr.querySelectorAll('td, th')) {
        cells.add(cell.text.trim());
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return TableBlock(rows);
  }

  bool _isPageBreak(Element el) {
    final epubType = el.attributes['epub:type'];
    if (epubType == 'pagebreak') return true;
    if (el.localName == 'span' && el.attributes.containsKey('title')) {
      return epubType == 'pagebreak';
    }
    return false;
  }
}
