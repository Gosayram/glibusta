import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import 'epub_models.dart';

List<TocItem> parseNavToc(String htmlText) {
  final doc = html_parser.parse(htmlText);
  final nav =
      doc.querySelector(r'nav[epub\:type="toc"]') ??
      doc.querySelector('nav[type="toc"]') ??
      doc.querySelector('nav');
  if (nav == null) return const [];
  final ol = nav.querySelector('ol');
  if (ol == null) return const [];
  return _parseTocOl(ol);
}

List<TocItem> _parseTocOl(Element ol) {
  final items = <TocItem>[];
  for (final li in ol.children.where((Element e) => e.localName == 'li')) {
    final a = li.querySelector('a');
    final span = li.querySelector('span');
    final title = (a?.text ?? span?.text ?? '').trim();
    final href = a?.attributes['href'] ?? '';
    final childOl = li.children.where((Element e) => e.localName == 'ol').firstOrNull;
    if (title.isNotEmpty) {
      items.add(
        TocItem(
          title: title,
          href: href,
          children: childOl == null ? const [] : _parseTocOl(childOl),
        ),
      );
    }
  }
  return items;
}

List<TocItem> parseNcx(String xmlText) {
  final doc = XmlDocument.parse(xmlText);
  final navMap = doc.findAllElements('navMap').firstOrNull;
  if (navMap == null) return const [];
  return navMap.findElements('navPoint').map(_parseNavPoint).toList();
}

TocItem _parseNavPoint(XmlElement navPoint) {
  final title =
      navPoint
          .findAllElements('navLabel')
          .firstOrNull
          ?.findAllElements('text')
          .firstOrNull
          ?.innerText
          .trim() ??
      'Глава';
  final href = navPoint.findAllElements('content').firstOrNull?.getAttribute('src') ?? '';
  final children = navPoint.findElements('navPoint').map(_parseNavPoint).toList();
  return TocItem(title: title, href: href, children: children);
}
