import '../data/parsers/normalized_book.dart';

class TocEntry {
  final int index;
  final String title;
  final int depth;
  final bool isGroup;
  final int groupId;
  final String? anchor;

  const TocEntry({
    required this.index,
    required this.title,
    required this.depth,
    required this.isGroup,
    required this.groupId,
    this.anchor,
  });
}

int detectTocDepth(String title) {
  final trimmed = title.trim();
  final match = RegExp(r'^(\d+(?:[.\-]\d+)*)\s').firstMatch(trimmed);
  if (match != null) {
    return match.group(1)!.split(RegExp(r'[.\-]')).length - 1;
  }
  if (trimmed.startsWith(RegExp(r'[IVX]+\s'))) return 1;
  return 0;
}

List<TocEntry> buildTocHierarchy(List<String> titles) {
  final items = <TocEntry>[];
  final depthStack = <({int depth, int groupId, String title})>[];

  for (var i = 0; i < titles.length; i++) {
    final title = i < titles.length ? titles[i] : '';
    final depth = detectTocDepth(title);

    while (depthStack.isNotEmpty && depthStack.last.depth >= depth) {
      depthStack.removeLast();
    }

    final groupId = depthStack.isNotEmpty ? depthStack.last.groupId : i;
    items.add(TocEntry(index: i, title: title, depth: depth, isGroup: false, groupId: groupId));
    depthStack.add((depth: depth, groupId: i, title: title));
  }

  final childGroupIds = <int>{};
  for (final item in items) {
    if (items.any((e) => e.groupId == item.index && e.index != item.index)) {
      childGroupIds.add(item.index);
    }
  }

  return items.map((item) {
    if (childGroupIds.contains(item.index)) {
      final titleIdx = depthStack.indexWhere((d) => d.groupId == item.index);
      return TocEntry(
        index: item.index,
        title: titleIdx >= 0 ? depthStack[titleIdx].title : item.title,
        depth: item.depth,
        isGroup: true,
        groupId: item.groupId,
      );
    }
    return item;
  }).toList();
}

const _maxTitleLength = 80;

String _truncateTitle(String title) {
  if (title.length <= _maxTitleLength) return title;
  return '${title.substring(0, _maxTitleLength - 1)}\u2026';
}

String _chapterFallbackTitle(List<String> chapterTitles, int chapterIndex) {
  if (chapterIndex < chapterTitles.length) {
    final t = chapterTitles[chapterIndex].trim();
    if (t.isNotEmpty) return _truncateTitle(t);
  }
  return 'Глава ${chapterIndex + 1}';
}

({int chapterIndex, int paragraphIndex})? resolveTocAnchor({
  required Map<String, dynamic>? metadata,
  required String? anchor,
  required int chapterIndex,
}) {
  if (anchor == null || anchor.isEmpty) return null;
  final anchors = metadata?['epubAnchors'];
  final chapterPaths = metadata?['epubChapterPaths'];
  if (anchors is! Map || chapterPaths is! List) return null;
  if (chapterIndex < 0 || chapterIndex >= chapterPaths.length) return null;
  final sourcePath = chapterPaths[chapterIndex];
  if (sourcePath is! String || sourcePath.isEmpty) return null;
  final key = '$sourcePath#$anchor';
  final value = anchors[key];
  if (value is! Map) return null;
  final resolvedChapter = value['chapterIndex'];
  final resolvedParagraph = value['paragraphIndex'];
  if (resolvedChapter is! int ||
      resolvedParagraph is! int ||
      resolvedChapter < 0 ||
      resolvedParagraph < 0) {
    return null;
  }
  return (chapterIndex: resolvedChapter, paragraphIndex: resolvedParagraph);
}

List<TocEntry> buildTocFromEpubToc(
  List<Map<String, dynamic>> epubTocItems,
) {
  final result = <TocEntry>[];
  void visit(List<Map<String, dynamic>> items, int depth) {
    for (final item in items) {
      final title = (item['title'] as String?) ?? '';
      final href = (item['href'] as String?) ?? '';
      final hashIndex = href.indexOf('#');
      final anchor = hashIndex >= 0 ? href.substring(hashIndex + 1) : null;
      if (title.isEmpty) continue;
      result.add(
        TocEntry(
          index: result.length,
          title: title,
          depth: depth,
          isGroup: false,
          groupId: result.length,
          anchor: anchor,
        ),
      );
      final children = item['children'];
      if (children is List && children.isNotEmpty) {
        visit(children.cast<Map<String, dynamic>>(), depth + 1);
      }
    }
  }

  visit(epubTocItems, 0);
  return result;
}

List<TocEntry> buildTocFromHeadings(
  List<String> chapterTitles,
  Map<int, ReaderChapter> loadedChapters,
) {
  final allHeadings = <({int chapterIndex, String title, int level})>[];
  for (final entry in loadedChapters.entries) {
    for (final block in entry.value.blocks) {
      if (block.type == BlockType.heading && block.headingLevel != null) {
        final text = block.text.trim();
        if (text.isNotEmpty) {
          allHeadings.add((
            chapterIndex: entry.key,
            title: text,
            level: block.headingLevel!,
          ));
        }
      }
    }
  }
  if (allHeadings.isEmpty) return buildTocHierarchy(chapterTitles);

  final minLevel = allHeadings.map((h) => h.level).reduce((a, b) => a < b ? a : b);

  final items = <TocEntry>[];
  var currentChapter = -1;

  for (var i = 0; i < allHeadings.length; i++) {
    final h = allHeadings[i];
    if (h.chapterIndex != currentChapter) {
      currentChapter = h.chapterIndex;
      final chTitle = _chapterFallbackTitle(chapterTitles, currentChapter);
      items.add(
        TocEntry(
          index: currentChapter,
          title: chTitle,
          depth: 0,
          isGroup: allHeadings.any((x) => x.chapterIndex == currentChapter && x != h),
          groupId: currentChapter,
        ),
      );
    }
    items.add(
      TocEntry(
        index: currentChapter,
        title: _truncateTitle(h.title),
        depth: h.level - minLevel + 1,
        isGroup: false,
        groupId: currentChapter,
      ),
    );
  }

  return items;
}
