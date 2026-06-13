import 'package:xml/xml.dart';

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
    final doc = XmlDocument.parse(htmlText);
    final body = _findBody(doc);
    if (body == null) return const [];
    return _processChildren(body, chapterPath);
  }

  XmlElement? _findBody(XmlDocument doc) {
    final root = doc.rootElement;
    if (root.localName == 'body') return root;
    for (final child in root.descendants.whereType<XmlElement>()) {
      if (child.localName == 'body') return child;
    }
    return null;
  }

  Future<List<ReaderBlock>> _processChildren(
    XmlElement parent,
    String chapterPath,
  ) async {
    final blocks = <ReaderBlock>[];
    for (final node in parent.children) {
      if (node is XmlText) {
        final text = node.value.trim();
        if (text.isNotEmpty) {
          blocks.add(ParagraphBlock([TextSpan(text: text)]));
        }
      } else if (node is XmlElement) {
        final block = await _processElement(node, chapterPath);
        if (block != null) {
          blocks.add(block);
        }
      }
    }
    return blocks;
  }

  Future<ReaderBlock?> _processElement(
    XmlElement el,
    String chapterPath,
  ) async {
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
        final level = int.parse(tag[1]);
        final text = el.innerText.trim();
        if (text.isEmpty) return null;
        return HeadingBlock(text, level);

      case 'img':
        return _processImage(el, chapterPath);

      case 'ul':
        return _processList(el, ordered: false, chapterPath: chapterPath);
      case 'ol':
        return _processList(el, ordered: true, chapterPath: chapterPath);

      case 'table':
        return _processTable(el);

      case 'blockquote':
        final text = el.innerText.trim();
        if (text.isEmpty) return null;
        return QuoteBlock(text);

      case 'hr':
        return const SeparatorBlock();

      case 'br':
        return null;

      case 'span':
        if (_isPageBreak(el)) {
          final epubType = el.getAttribute('epub:type');
          final label = epubType == 'pagebreak'
              ? (el.getAttribute('title') ?? el.getAttribute('id') ?? '')
              : (el.getAttribute('title') ?? '');
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

  List<TextSpan> _extractInlineSpans(XmlElement el, String chapterPath) {
    final spans = <TextSpan>[];
    _walkInline(el, spans, chapterPath, bold: false, italic: false, superscript: false);
    return spans;
  }

  void _walkInline(
    XmlElement el,
    List<TextSpan> spans,
    String chapterPath, {
    required bool bold,
    required bool italic,
    required bool superscript,
    String? href,
  }) {
    for (final node in el.children) {
      if (node is XmlText) {
        final text = node.value;
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
      } else if (node is XmlElement) {
        final tag = node.localName;
        var newBold = bold;
        var newItalic = italic;
        var newSuperscript = superscript;
        String? newHref = href;

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
            newHref = node.getAttribute('href');
            break;
          case 'img':
            continue;
          case 'br':
            spans.add(const TextSpan(text: '\n'));
            continue;
          default:
            break;
        }

        final xmlChildren = node.children;
        if (tag == 'a' && xmlChildren.length == 1 && xmlChildren.first is XmlText) {
          final text = (xmlChildren.first as XmlText).value;
          if (text.isNotEmpty) {
            spans.add(
              TextSpan(
                text: text,
                bold: newBold,
                italic: newItalic,
                superscript: newSuperscript,
                href: newHref,
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
          href: newHref,
        );
      }
    }
  }

  Future<ReaderBlock?> _processImage(XmlElement el, String chapterPath) async {
    final src = el.getAttribute('src');
    if (src == null || src.isEmpty) return null;
    final resource = resolver.resolveFromHref(chapterPath: chapterPath, href: src);
    if (resource == null) return null;
    final localPath = await imageStore.saveImage(epub: epub, resource: resource);
    return ImageBlock(
      resourceId: resource.id,
      localPath: localPath,
      alt: el.getAttribute('alt'),
    );
  }

  Future<ListBlock> _processList(
    XmlElement el, {
    required bool ordered,
    required String chapterPath,
  }) async {
    final items = <String>[];
    for (final child in el.children.whereType<XmlElement>()) {
      if (child.localName == 'li') {
        final text = child.innerText.trim();
        if (text.isNotEmpty) items.add(text);
      }
    }
    return ListBlock(ordered: ordered, items: items);
  }

  Future<TableBlock> _processTable(XmlElement el) async {
    final rows = <List<String>>[];
    for (final tr in el.findAllElements('tr')) {
      final cells = <String>[];
      for (final cell in tr.findAllElements('td').followedBy(tr.findAllElements('th'))) {
        cells.add(cell.innerText.trim());
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return TableBlock(rows);
  }

  bool _isPageBreak(XmlElement el) {
    final epubType = el.getAttribute('epub:type');
    if (epubType == 'pagebreak') return true;
    if (el.localName == 'span' && el.getAttribute('title') != null) {
      return true;
    }
    return false;
  }
}
