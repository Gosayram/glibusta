import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'epub_archive.dart';
import 'epub_models.dart';

final class EpubOpfData {
  const EpubOpfData({
    required this.title,
    required this.authors,
    this.language,
    this.description,
    required this.resources,
    required this.spineItems,
    required this.opfDir,
    this.coverId,
    this.isFixedLayout = false,
  });
  final String title;
  final List<String> authors;
  final String? language;
  final String? description;
  final Map<String, EpubResource> resources;
  final List<SpineItem> spineItems;
  final String opfDir;
  final String? coverId;
  final bool isFixedLayout;
}

final class SpineItem {
  const SpineItem({required this.idref, this.linear = true});
  final String idref;
  final bool linear;
}

final class EpubOpfParser {
  EpubOpfData parse({required EpubArchive epub, required String opfPath}) {
    final opfText = epub.readText(opfPath);
    final doc = XmlDocument.parse(opfText);
    final opfDir = p.posix.dirname(opfPath) == '.' ? '' : p.posix.dirname(opfPath);

    // Metadata — EPUB 2 uses dc: namespace, EPUS 3 may use plain names
    const dcNs = 'http://purl.org/dc/elements/1.1/';
    final metadata = doc.findAllElements('metadata').firstOrNull;
    String findMeta(String tag) {
      return metadata?.findAllElements(tag, namespace: dcNs).firstOrNull?.innerText.trim() ??
          metadata?.findAllElements(tag).firstOrNull?.innerText.trim() ??
          '';
    }

    final title = findMeta('title').isNotEmpty ? findMeta('title') : 'Без названия';
    final allCreators = metadata?.findAllElements('creator', namespace: dcNs).toList() ??
        metadata?.findAllElements('creator').toList() ??
        [];
    final authors = allCreators
        .map((e) => e.innerText.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final language = findMeta('language');
    final description = findMeta('description');
    final coverId = metadata
        ?.findAllElements('meta')
        .where((e) => e.getAttribute('name') == 'cover')
        .map((e) => e.getAttribute('content'))
        .firstOrNull;

    // Fixed layout detection
    final layout = metadata
        ?.findAllElements('meta')
        .where((e) => e.getAttribute('property') == 'rendition:layout')
        .map((e) => e.innerText.trim())
        .firstOrNull;
    final isFixedLayout = layout == 'pre-paginated';

    // Manifest
    final manifestItems =
        doc.findAllElements('manifest').firstOrNull?.findElements('item') ?? const [];
    final resources = <String, EpubResource>{};
    for (final item in manifestItems) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;
      final fullPath = _resolvePath(opfDir, href);
      final props = _parseProperties(item.getAttribute('properties'));
      resources[id] = EpubResource(
        id: id,
        href: href,
        fullPath: fullPath,
        mediaType: mediaType,
        properties: props,
        type: _resourceType(mediaType, props),
      );
    }

    // Spine
    final spineItems =
        doc
            .findAllElements('spine')
            .firstOrNull
            ?.findElements('itemref')
            .map(
              (e) => SpineItem(
                idref: e.getAttribute('idref')!,
                linear: e.getAttribute('linear') != 'no',
              ),
            )
            .toList() ??
        const [];

    return EpubOpfData(
      title: title,
      authors: authors,
      language: language,
      description: description,
      resources: resources,
      spineItems: spineItems,
      opfDir: opfDir,
      coverId: coverId,
      isFixedLayout: isFixedLayout,
    );
  }

  Set<String> _parseProperties(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    return value.split(RegExp(r'\s+')).map((e) => e.trim()).toSet();
  }

  String _resolvePath(String baseDir, String href) {
    final decodedHref = Uri.decodeFull(href.split('#').first);
    if (baseDir.isEmpty) return p.posix.normalize(decodedHref);
    return p.posix.normalize(p.posix.join(baseDir, decodedHref));
  }

  EpubResourceType _resourceType(String mediaType, Set<String> properties) {
    if (mediaType == 'application/xhtml+xml') {
      return properties.contains('nav') ? EpubResourceType.nav : EpubResourceType.xhtml;
    }
    if (mediaType == 'text/css') return EpubResourceType.css;
    if (mediaType.startsWith('image/')) return EpubResourceType.image;
    if (mediaType == 'application/x-dtbncx+xml') return EpubResourceType.ncx;
    if (mediaType.contains('font')) return EpubResourceType.font;
    return EpubResourceType.unknown;
  }
}
