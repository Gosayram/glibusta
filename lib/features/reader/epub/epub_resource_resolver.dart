import 'package:path/path.dart' as p;

import 'epub_models.dart';

/// Retains only links that the native reader can navigate or explicitly offer
/// to open outside the app. EPUB content is never executed as web content.
String? sanitizeEpubLinkHref(String? href) {
  final trimmed = href?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final colon = trimmed.indexOf(':');
  if (colon < 0) return trimmed;
  final scheme = String.fromCharCodes(
    trimmed.codeUnits.take(colon).where((unit) => unit > 0x20 && unit != 0x7f),
  ).toLowerCase();

  return switch (scheme) {
    'http' || 'https' => trimmed,
    _ => null,
  };
}

final class EpubResourceResolver {
  EpubResourceResolver(this.resources);
  final Map<String, EpubResource> resources;

  EpubResource? resolveFromHref({required String chapterPath, required String href}) {
    final cleanHref = Uri.decodeFull(href.split('#').first);
    if (cleanHref.isEmpty) return null;
    if (Uri.tryParse(cleanHref)?.hasScheme ?? false) return null;
    final chapterDir = p.posix.dirname(chapterPath);
    final fullPath = p.posix.normalize(p.posix.join(chapterDir, cleanHref));
    if (_isUnsafePath(fullPath)) return null;
    for (final resource in resources.values) {
      if (resource.fullPath == fullPath) return resource;
    }
    return null;
  }

  static bool _isUnsafePath(String path) {
    if (path.startsWith('/')) return true;
    final segments = p.posix.split(path);
    return segments.any((s) => s == '..');
  }
}
