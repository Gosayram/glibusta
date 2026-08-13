import 'package:path/path.dart' as p;

/// Resolves an internal EPUB href using the index persisted in book metadata.
///
/// The parser stores archive-relative chapter paths because EPUB references are
/// relative to the source XHTML document, not the OPF file.
({int chapterIndex, int paragraphIndex})? resolveEpubAnchorTarget({
  required Map<String, dynamic>? metadata,
  required int currentChapterIndex,
  required String href,
}) {
  final anchors = metadata?['epubAnchors'];
  final chapterPaths = metadata?['epubChapterPaths'];
  if (anchors is! Map || chapterPaths is! List) return null;
  if (currentChapterIndex < 0 || currentChapterIndex >= chapterPaths.length) return null;
  if (href.startsWith('//') || Uri.tryParse(href)?.hasScheme == true) return null;

  final sourcePath = chapterPaths[currentChapterIndex];
  if (sourcePath is! String || sourcePath.isEmpty) return null;

  final hashIndex = href.indexOf('#');
  final rawPath = hashIndex < 0 ? href : href.substring(0, hashIndex);
  final rawFragment = hashIndex < 0 ? null : href.substring(hashIndex + 1);
  final targetPath = _resolvePath(sourcePath, rawPath);
  if (targetPath == null) return null;

  String? fragment;
  if (rawFragment != null && rawFragment.isNotEmpty) {
    if (_hasMalformedPercentEscape(rawFragment)) return null;
    fragment = Uri.decodeComponent(rawFragment);
  }
  final key = fragment == null ? targetPath : '$targetPath#$fragment';
  final value = anchors[key];
  if (value is! Map) return null;
  final chapterIndex = value['chapterIndex'];
  final paragraphIndex = value['paragraphIndex'];
  if (chapterIndex is! int ||
      paragraphIndex is! int ||
      chapterIndex < 0 ||
      chapterIndex >= chapterPaths.length ||
      paragraphIndex < 0) {
    return null;
  }
  return (chapterIndex: chapterIndex, paragraphIndex: paragraphIndex);
}

String? _resolvePath(String sourcePath, String rawPath) {
  if (_hasMalformedPercentEscape(rawPath)) {
    return null;
  }
  final decodedPath = Uri.decodeFull(rawPath);
  if (decodedPath.isEmpty) return sourcePath;
  final target = p.posix.normalize(p.posix.join(p.posix.dirname(sourcePath), decodedPath));
  if (target.startsWith('/') || p.posix.split(target).any((segment) => segment == '..')) {
    return null;
  }
  return target;
}

bool _hasMalformedPercentEscape(String value) => RegExp(r'%(?![0-9A-Fa-f]{2})').hasMatch(value);
