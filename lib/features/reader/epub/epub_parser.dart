import 'dart:async';

import 'package:collection/collection.dart';

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

    final toc = await _parseToc(epub, opf, resolver);

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
      textDirection ??= result.textDirection;
      final title = _extractTitle(result.blocks);

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
        ),
      );
      chapterCount++;
      if (chapterCount % 5 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final coverPath = await _extractCover(epub: epub, opf: opf);

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

  Future<List<TocItem>?> _parseToc(
    EpubArchive epub,
    EpubOpfData opf,
    EpubResourceResolver resolver,
  ) async {
    final navResource = opf.resources.values.firstWhereOrNull((EpubResource r) => r.isNav);
    if (navResource != null) {
      try {
        final navText = epub.readText(navResource.fullPath);
        final toc = parseNavToc(navText);
        if (toc.isNotEmpty) return toc;
      } on Object catch (_) {}
    }
    final ncxResource = opf.resources.values.firstWhereOrNull(
      (EpubResource r) => r.type == EpubResourceType.ncx,
    );
    if (ncxResource != null) {
      try {
        final ncxText = epub.readText(ncxResource.fullPath);
        return parseNcx(ncxText);
      } on Object catch (_) {}
    }
    return null;
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
        (EpubResource r) => r.type == EpubResourceType.image && r.id.toLowerCase().contains('cover'),
      ),
    ];
    return candidates.whereType<EpubResource>().firstWhereOrNull(
      (EpubResource resource) => isSupportedImage(resource.mediaType),
    );
  }
}
