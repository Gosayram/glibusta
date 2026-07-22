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

  static const Set<String> _nonReaderElements = <String>{
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'template',
  };

  Future<
    ({
      List<ReaderBlock> blocks,
      List<EpubCssRule>? styles,
      String? textDirection,
    })
  >
  parseChapter({
    required String chapterPath,
    required String htmlText,
  }) async {
    final doc = XmlDocument.parse(htmlText);
    final styles = await _extractCss(doc, chapterPath);
    final body = _findBody(doc);
    if (body == null) return (blocks: const <ReaderBlock>[], styles: styles, textDirection: null);
    final blocks = await _processChildren(body, chapterPath);
    final direction = (doc.rootElement.getAttribute('dir') ?? body.getAttribute('dir'))
        ?.toLowerCase();
    return (
      blocks: blocks,
      styles: styles,
      textDirection: direction == 'rtl' || direction == 'ltr' ? direction : null,
    );
  }

  /// Whether [htmlText] is only a spine wrapper for the selected cover image.
  /// The reader inserts its own cover page, so retaining this document would
  /// show the same image twice.
  bool isSingleCoverImageDocument({
    required String chapterPath,
    required String htmlText,
    required EpubResource cover,
  }) {
    try {
      final body = _findBody(XmlDocument.parse(htmlText));
      if (body == null || body.innerText.trim().isNotEmpty) return false;
      final images = body.descendants.whereType<XmlElement>().where(
        (element) => element.localName == 'img' || element.localName == 'image',
      );
      final image = images.length == 1 ? images.single : null;
      if (image == null) return false;
      final href = image.localName == 'img'
          ? image.getAttribute('src')
          : _attributeByLocalName(image, 'href');
      if (href == null || href.isEmpty) return false;
      final resolved = resolver.resolveFromHref(chapterPath: chapterPath, href: href);
      return resolved?.fullPath == cover.fullPath;
    } on Object catch (_) {
      return false;
    }
  }

  String? _attributeByLocalName(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  /// Extract supported CSS rules in source order so the adapter can apply the
  /// CSS cascade rather than the order of classes in the XHTML attribute.
  Future<List<EpubCssRule>?> _extractCss(XmlDocument doc, String chapterPath) async {
    List<EpubCssRule>? rules;
    for (final element in doc.descendants.whereType<XmlElement>()) {
      final String? text;
      if (element.localName == 'style') {
        text = element.innerText;
      } else if (element.localName == 'link' && _isStylesheetLink(element)) {
        final href = element.getAttribute('href');
        final resource = href == null
            ? null
            : resolver.resolveFromHref(chapterPath: chapterPath, href: href);
        if (resource == null || resource.type != EpubResourceType.css) continue;
        try {
          text = epub.readText(resource.fullPath);
        } on Object catch (_) {
          continue;
        }
      } else {
        continue;
      }
      final trimmedText = _expandSupportedMediaRules(_stripCssComments(text)).trim();
      if (trimmedText.isEmpty) continue;
      for (final raw in trimmedText.split('}')) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        final brace = trimmed.indexOf('{');
        if (brace < 0) continue;
        final selectors = trimmed.substring(0, brace).split(',');
        final body = trimmed.substring(brace + 1).trim();
        if (body.isEmpty) continue;
        final properties = _parseCssBody(body);
        if (properties.isEmpty) continue;
        for (final rawSelector in selectors) {
          final selector = rawSelector.trim();
          if (!_isSupportedParagraphSelector(selector)) continue;
          (rules ??= []).add(EpubCssRule(selector: selector, properties: properties));
        }
      }
    }
    return rules;
  }

  bool _isStylesheetLink(XmlElement element) => (element.getAttribute('rel') ?? '')
      .split(RegExp(r'\s+'))
      .any((value) => value.toLowerCase() == 'stylesheet');

  String _stripCssComments(String text) => text.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

  /// Keeps rules from CSS media blocks that unambiguously target the reader.
  /// Viewport-dependent and print rules are intentionally ignored because this
  /// lightweight parser does not evaluate media features.
  String _expandSupportedMediaRules(String text) {
    final result = StringBuffer();
    var index = 0;
    while (index < text.length) {
      final mediaStart = text.toLowerCase().indexOf('@media', index);
      if (mediaStart < 0) {
        result.write(text.substring(index));
        break;
      }
      result.write(text.substring(index, mediaStart));
      final openBrace = text.indexOf('{', mediaStart);
      if (openBrace < 0) {
        result.write(text.substring(mediaStart));
        break;
      }
      var depth = 1;
      var closeBrace = openBrace + 1;
      while (closeBrace < text.length && depth > 0) {
        final character = text[closeBrace];
        if (character == '{') depth++;
        if (character == '}') depth--;
        closeBrace++;
      }
      if (depth != 0) {
        result.write(text.substring(mediaStart));
        break;
      }
      final query = text.substring(mediaStart + '@media'.length, openBrace).trim().toLowerCase();
      if (query == 'screen' ||
          query == 'all' ||
          query.startsWith('screen ') ||
          query.startsWith('all ')) {
        result.write(_expandSupportedMediaRules(text.substring(openBrace + 1, closeBrace - 1)));
      }
      index = closeBrace;
    }
    return result.toString();
  }

  bool _isSupportedParagraphSelector(String selector) =>
      selector == 'p' ||
      RegExp(r'^\.[-_a-zA-Z][-_a-zA-Z0-9]*$').hasMatch(selector) ||
      RegExp(r'^p\.[-_a-zA-Z][-_a-zA-Z0-9]*$').hasMatch(selector);

  Map<String, String> _parseCssBody(String body) {
    final props = <String, String>{};
    for (final decl in body.split(';')) {
      final d = decl.trim();
      if (d.isEmpty) continue;
      final colon = d.indexOf(':');
      if (colon < 0) continue;
      final name = d.substring(0, colon).trim().toLowerCase();
      final value = d.substring(colon + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) {
        props[name] = value;
      }
    }
    return props;
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
    if (_nonReaderElements.contains(tag)) return null;
    switch (tag) {
      case 'p':
        final spans = _extractInlineSpans(el, chapterPath);
        if (spans.isEmpty) return null;
        return ParagraphBlock(
          spans,
          cssClasses: _cssClasses(el),
          inlineStyles: _parseCssBody(el.getAttribute('style') ?? ''),
          anchorId: el.getAttribute('id'),
          anchorIds: _anchorIds(el),
        );
      case 'div':
      case 'section':
        final childBlocks = await _processChildren(el, chapterPath);
        if (childBlocks.isEmpty) return null;
        _attachContainerAnchor(childBlocks, el.getAttribute('id'));
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
        return HeadingBlock(
          text,
          level,
          anchorId: el.getAttribute('id'),
          anchorIds: _anchorIds(el),
        );

      case 'figure':
        return _processFigure(el, chapterPath);

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
        return ParagraphBlock(
          spans,
          anchorId: el.getAttribute('id'),
          anchorIds: _anchorIds(el),
        );

      default:
        final childBlocks = await _processChildren(el, chapterPath);
        if (childBlocks.isEmpty) return null;
        _attachContainerAnchor(childBlocks, el.getAttribute('id'));
        if (childBlocks.length == 1) return childBlocks.first;
        return SectionBlock(childBlocks);
    }
  }

  List<String> _cssClasses(XmlElement el) {
    final value = el.getAttribute('class');
    if (value == null || value.trim().isEmpty) return const [];
    return value.split(RegExp(r'\s+')).where((cssClass) => cssClass.isNotEmpty).toList();
  }

  List<String> _anchorIds(XmlElement el) {
    final ids = <String>{};
    for (final element in [el, ...el.descendants.whereType<XmlElement>()]) {
      final id = element.getAttribute('id');
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids.toList(growable: false);
  }

  void _attachContainerAnchor(List<ReaderBlock> blocks, String? anchorId) {
    if (anchorId == null || anchorId.isEmpty) return;
    final first = blocks.first;
    blocks[0] = switch (first) {
      ParagraphBlock() => ParagraphBlock(
        first.spans,
        cssClasses: first.cssClasses,
        inlineStyles: first.inlineStyles,
        anchorId: first.anchorId ?? anchorId,
        anchorIds: {anchorId, ...first.anchorIds}.toList(growable: false),
      ),
      HeadingBlock() => HeadingBlock(
        first.text,
        first.level,
        anchorId: first.anchorId ?? anchorId,
        anchorIds: {anchorId, ...first.anchorIds}.toList(growable: false),
      ),
      _ => first,
    };
  }

  List<TextSpan> _extractInlineSpans(XmlElement el, String chapterPath) {
    final spans = <TextSpan>[];
    _walkInline(el, spans, chapterPath, bold: false, italic: false, superscript: false);
    return spans;
  }

  /// HG-17.2: extract CSS color value from inline style attribute.
  String? _styleColor(String? style) {
    if (style == null) return null;
    final lower = style.toLowerCase();
    final idx = lower.indexOf('color:');
    if (idx < 0) return null;
    // Skip if it's background-color
    if (idx > 4 && lower.substring(idx - 11, idx) == 'background') return null;
    var val = style.substring(idx + 6).trim();
    final end = val.indexOf(';');
    if (end >= 0) val = val.substring(0, end);
    val = val.trim();
    return val.isEmpty ? null : val;
  }

  void _walkInline(
    XmlElement el,
    List<TextSpan> spans,
    String chapterPath, {
    required bool bold,
    required bool italic,
    required bool superscript,
    String? href,
    String? color,
  }) {
    // HG-17.2: inherit parent color, override if this element has its own
    color ??= _styleColor(el.getAttribute('style'));
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
              color: color,
            ),
          );
        }
      } else if (node is XmlElement) {
        final tag = node.localName;
        if (_nonReaderElements.contains(tag)) continue;
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

        if (tag == 'a' && node.children.length == 1 && node.children.first is XmlText) {
          final text = (node.children.first as XmlText).value;
          if (text.isNotEmpty) {
            spans.add(
              TextSpan(
                text: text,
                bold: newBold,
                italic: newItalic,
                superscript: newSuperscript,
                href: newHref,
                color: color,
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
          color: color,
        );
      }
    }
  }

  Future<ReaderBlock?> _processFigure(XmlElement el, String chapterPath) async {
    // Look for <img> inside <figure>
    XmlElement? imgEl;
    String? caption;
    for (final child in el.descendants.whereType<XmlElement>()) {
      if (child.localName == 'img' && imgEl == null) {
        imgEl = child;
      } else if (child.localName == 'figcaption' && caption == null) {
        caption = child.innerText.trim();
      }
    }
    if (imgEl == null) return null;
    final imgResult = await _processImage(imgEl, chapterPath);
    if (imgResult == null || imgResult is! ImageBlock) return null;
    if (caption != null && caption.isNotEmpty) {
      return ImageBlock(
        resourceId: imgResult.resourceId,
        localPath: imgResult.localPath,
        alt: imgResult.alt,
        caption: caption,
      );
    }
    return imgResult;
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
      for (final child in tr.childElements) {
        if (child.localName == 'td' || child.localName == 'th') {
          cells.add(child.innerText.trim());
        }
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return TableBlock(rows);
  }

  bool _isPageBreak(XmlElement el) {
    final epubType = el.getAttribute('epub:type');
    if (epubType == 'pagebreak') return true;
    if (el.localName == 'hr' && el.getAttribute('role') == 'separator') return true;
    return false;
  }
}
