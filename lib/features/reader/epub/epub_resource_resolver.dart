import 'package:path/path.dart' as p;

import 'epub_models.dart';

final class EpubResourceResolver {
  EpubResourceResolver(this.resources);
  final Map<String, EpubResource> resources;

  EpubResource? resolveFromHref({required String chapterPath, required String href}) {
    final cleanHref = Uri.decodeFull(href.split('#').first);
    if (cleanHref.isEmpty) return null;
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
