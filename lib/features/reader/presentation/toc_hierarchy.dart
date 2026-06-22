class TocEntry {
  final int index;
  final String title;
  final int depth;
  final bool isGroup;
  final int groupId;

  const TocEntry({
    required this.index,
    required this.title,
    required this.depth,
    required this.isGroup,
    required this.groupId,
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
