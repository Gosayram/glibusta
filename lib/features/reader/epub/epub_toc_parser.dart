import 'package:xml/xml.dart';

import 'epub_models.dart';

List<TocItem> parseNavToc(String htmlText) {
  final doc = XmlDocument.parse(htmlText);
  final nav = _findNav(doc);
  if (nav == null) return const [];
  final ol = nav.findElements('ol').firstOrNull;
  if (ol == null) return const [];
  return _parseTocOl(ol);
}

XmlElement? _findNav(XmlDocument doc) {
  for (final el in doc.findAllElements('nav')) {
    final epubType = el.getAttribute('epub:type') ?? el.getAttribute('type') ?? '';
    if (epubType == 'toc') return el;
  }
  return doc.findAllElements('nav').firstOrNull;
}

List<TocItem> _parseTocOl(XmlElement ol) {
  final items = <TocItem>[];
  for (final li in ol.findElements('li')) {
    final a = _findDescendantElement(li, 'a');
    final span = _findDescendantElement(li, 'span');
    final title = (a?.innerText ?? span?.innerText ?? '').trim();
    final href = a?.getAttribute('href') ?? '';
    final childOl = li.findElements('ol').firstOrNull;
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

XmlElement? _findDescendantElement(XmlElement parent, String localName) {
  for (final el in parent.descendants) {
    if (el is XmlElement && el.localName == localName) return el;
  }
  return null;
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
