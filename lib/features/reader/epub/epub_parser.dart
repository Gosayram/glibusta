import 'dart:async';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../data/parsers/smil_parser.dart';
import 'epub_archive.dart';
import 'epub_container_parser.dart';
import 'epub_html_parser.dart';
import 'epub_image_store.dart';
import 'epub_models.dart';
import 'epub_opf_parser.dart';
import 'epub_resource_resolver.dart';
import 'epub_toc_parser.dart';

final class CustomEpubParser {
  CustomEpubParser({required this.imageStore});
  final EpubImageStore imageStore;

  Future<EpubBook> parse(String filePath) async {
    final epub = await EpubArchive.open(filePath);
    final opfPath = EpubContainerParser().parseOpfPath(epub);
    final opf = EpubOpfParser().parse(epub: epub, opfPath: opfPath);
    final resolver = EpubResourceResolver(opf.resources);
    final htmlParser = EpubHtmlParser(
      resolver: resolver,
      imageStore: imageStore,
      epub: epub,
    );
    final coverResource = _findCoverResource(opf);

    final tocResult = await _parseToc(epub, opf, resolver);
    final toc = tocResult?.items;
    // Map each spine file to its TOC title so chapter names always match the
    // table of contents (содержание), not the first rendered heading.
    final tocTitleByPath = <String, String>{};
    if (tocResult != null) {
      final baseDir = tocResult.basePath.contains('/')
          ? tocResult.basePath.substring(0, tocResult.basePath.lastIndexOf('/'))
          : '';
      _collectTocTitles(tocResult.items, baseDir, tocTitleByPath);
    }

    final chapters = <EpubChapter>[];
    String? textDirection;
    var chapterCount = 0;
    for (final spineItem in opf.spineItems) {
      final resource = opf.resources[spineItem.idref];
      if (resource == null || resource.type != EpubResourceType.xhtml) continue;
      final htmlText = epub.readText(resource.fullPath);
      if (coverResource != null &&
          htmlParser.isSingleCoverImageDocument(
            chapterPath: resource.fullPath,
            htmlText: htmlText,
            cover: coverResource,
          )) {
        continue;
      }
      final result = await htmlParser.parseChapter(
        chapterPath: resource.fullPath,
        htmlText: htmlText,
      );
      // Empty spine documents are commonly used for publisher-specific
      // navigation and must not become reader pages with no content.
      if (result.blocks.isEmpty) continue;

      textDirection ??= result.textDirection;
      final tocTitle = tocTitleByPath[resource.fullPath];
      final title =
          tocTitle != null && tocTitle.isNotEmpty ? tocTitle : _extractTitle(result.blocks);

      // LW-6.1: Parse SMIL media overlay if present
      final List<SmilEntry>? smilEntries;
      if (spineItem.mediaOverlay != null) {
        smilEntries = await _parseSmilForChapter(epub, opf, spineItem.mediaOverlay!);
      } else {
        smilEntries = null;
      }

      chapters.add(
        EpubChapter(
          id: resource.id,
          href: resource.href,
          title: title,
          blocks: result.blocks,
          styles: result.styles,
          linear: spineItem.linear,
          smilEntries: smilEntries,
          textDirection: result.textDirection,
          fullPath: resource.fullPath,
        ),
      );
      chapterCount++;
      if (chapterCount % 5 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final coverPath = await _extractCover(epub: epub, opf: opf);
    final fonts = _extractFonts(epub, opf);

    return EpubBook(
      title: opf.title,
      authors: opf.authors,
      language: opf.language,
      description: opf.description,
      chapters: chapters,
      resources: opf.resources,
      toc: toc,
      coverImagePath: coverPath,
      isFixedLayout: opf.isFixedLayout,
      textDirection: textDirection,
      fonts: fonts,
    );
  }

  /// LW-6.1: Parse SMIL file referenced by a spine item's media-overlay attribute.
  Future<List<SmilEntry>?> _parseSmilForChapter(
    EpubArchive epub,
    EpubOpfData opf,
    String smilId,
  ) async {
    final smilResource = opf.resources[smilId];
    if (smilResource == null || !smilResource.href.endsWith('.smil')) return null;
    try {
      final smilText = epub.readText(smilResource.fullPath);
      final entries = SmilParser.parse(smilText);
      if (entries.isEmpty) return null;

      final audioPaths = <String, String?>{};
      final resolvedEntries = <SmilEntry>[];
      for (final entry in entries) {
        var audioPath = audioPaths[entry.audioSrc];
        if (!audioPaths.containsKey(entry.audioSrc)) {
          audioPath = await imageStore.saveAudio(
            epub: epub,
            smilPath: smilResource.fullPath,
            audioHref: entry.audioSrc,
          );
          audioPaths[entry.audioSrc] = audioPath;
        }
        resolvedEntries.add(
          SmilEntry(
            textRef: entry.textRef,
            paragraphId: entry.paragraphId,
            audioSrc: audioPath ?? entry.audioSrc,
            clipBegin: entry.clipBegin,
            clipEnd: entry.clipEnd,
          ),
        );
      }
      return resolvedEntries;
    } on Object catch (_) {
      return null;
    }
  }

  Future<({List<TocItem> items, String basePath})?> _parseToc(
    EpubArchive epub,
    EpubOpfData opf,
    EpubResourceResolver resolver,
  ) async {
    final navResource = opf.resources.values.firstWhereOrNull((EpubResource r) => r.isNav);
    if (navResource != null) {
      try {
        final navText = epub.readText(navResource.fullPath);
        final toc = parseNavToc(navText);
        if (toc.isNotEmpty) return (items: toc, basePath: navResource.fullPath);
      } on Object catch (_) {}
    }
    final ncxResource = opf.resources.values.firstWhereOrNull(
      (EpubResource r) => r.type == EpubResourceType.ncx,
    );
    if (ncxResource != null) {
      try {
        final ncxText = epub.readText(ncxResource.fullPath);
        final toc = parseNcx(ncxText);
        if (toc.isNotEmpty) return (items: toc, basePath: ncxResource.fullPath);
      } on Object catch (_) {}
    }
    return null;
  }

  /// Flattens the (possibly nested) TOC into a map of resolved archive path →
  /// title. The first TOC entry referencing a file wins, matching the usual
  /// convention that the chapter label precedes sub-section labels.
  void _collectTocTitles(List<TocItem> items, String baseDir, Map<String, String> out) {
    for (final item in items) {
      final hrefPath = Uri.decodeFull(item.href.split('#').first);
      if (hrefPath.isNotEmpty && !hrefPath.contains('://')) {
        final resolved = p.posix.normalize(p.posix.join(baseDir, hrefPath));
        final title = item.title.trim();
        if (title.isNotEmpty) out.putIfAbsent(resolved, () => title);
      }
      if (item.children.isNotEmpty) {
        _collectTocTitles(item.children, baseDir, out);
      }
    }
  }

  String _extractTitle(List<ReaderBlock> blocks) {
    for (final block in blocks) {
      if (block is HeadingBlock && block.text.isNotEmpty) return block.text;
    }
    for (final block in blocks) {
      if (block is ParagraphBlock && block.spans.isNotEmpty) {
        final text = block.spans.map((s) => s.text).join();
        if (text.length > 3) {
          return text.length > 80 ? '${text.substring(0, 80)}...' : text;
        }
      }
    }
    return '';
  }

  Future<String?> _extractCover({
    required EpubArchive epub,
    required EpubOpfData opf,
  }) async {
    final cover = _findCoverResource(opf);
    if (cover == null || !isSupportedImage(cover.mediaType)) return null;
    return imageStore.saveImage(epub: epub, resource: cover);
  }

  EpubResource? _findCoverResource(EpubOpfData opf) {
    final coverId = opf.coverId;
    final candidates = <EpubResource?>[
      if (coverId != null) opf.resources[coverId],
      opf.resources.values.firstWhereOrNull((EpubResource r) => r.isCoverImage),
      opf.resources.values.firstWhereOrNull(
        (EpubResource r) =>
            r.type == EpubResourceType.image && r.id.toLowerCase().contains('cover'),
      ),
    ];
    return candidates.whereType<EpubResource>().firstWhereOrNull(
      (EpubResource resource) => isSupportedImage(resource.mediaType),
    );
  }

  Map<String, String> _extractFonts(EpubArchive epub, EpubOpfData opf) {
    final fonts = <String, String>{};
    for (final resource in opf.resources.values) {
      if (resource.type != EpubResourceType.css) continue;
      try {
        final css = epub.readText(resource.fullPath);
        _parseFontFaces(css, resource.fullPath, fonts);
      } on Object catch (_) {}
    }
    return fonts;
  }

  static final _fontFaceRe = RegExp(r'@font-face\s*\{');
  static final _fontFamilyRe = RegExp(r'font-family\s*:\s*["\x27]?([^"\x27;}]+)');
  static final _srcRe = RegExp(r'src\s*:.*?url\s*\(\s*["\x27]?([^"\x27)]+)');

  void _parseFontFaces(String css, String cssPath, Map<String, String> fonts) {
    var pos = 0;
    while (pos < css.length) {
      final match = _fontFaceRe.firstMatch(css.substring(pos));
      if (match == null) break;
      final blockStart = pos + match.end;
      var depth = 1;
      var j = blockStart;
      while (j < css.length && depth > 0) {
        if (css[j] == '{') depth++;
        if (css[j] == '}') depth--;
        j++;
      }
      final block = css.substring(blockStart, j - 1);
      final familyMatch = _fontFamilyRe.firstMatch(block);
      final srcMatch = _srcRe.firstMatch(block);
      if (familyMatch != null && srcMatch != null) {
        final family = familyMatch.group(1)!.trim();
        final src = srcMatch.group(1)!.trim();
        if (family.isNotEmpty && src.isNotEmpty) {
          final resolved = _resolveCssHref(cssPath, src);
          fonts.putIfAbsent(family, () => resolved);
        }
      }
      pos = j;
    }
  }

  String _resolveCssHref(String cssPath, String href) {
    if (href.startsWith('/') || href.contains('://')) return href;
    final lastSlash = cssPath.lastIndexOf('/');
    if (lastSlash < 0) return href;
    return '${cssPath.substring(0, lastSlash)}/$href';
  }
}
