import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'epub_archive.dart';
import 'epub_models.dart';

final class EpubImageStore {
  EpubImageStore(this.cacheDir);
  final Directory cacheDir;

  Future<String> saveImage({required EpubArchive epub, required EpubResource resource}) async {
    final bytes = epub.readBytes(resource.fullPath);
    final hash = sha256.convert(bytes).toString();
    final extension = _extensionFor(resource.mediaType, resource.fullPath);
    final file = File(p.join(cacheDir.path, '$hash$extension'));
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  /// Extracts a media-overlay audio resource to the per-book cache.
  ///
  /// SMIL paths are relative to the SMIL file, not to the XHTML chapter.
  /// Reject absolute and traversal paths before accessing the archive.
  Future<String?> saveAudio({
    required EpubArchive epub,
    required String smilPath,
    required String audioHref,
  }) async {
    final href = Uri.decodeFull(audioHref.split('#').first);
    if (href.isEmpty || Uri.tryParse(href)?.hasScheme == true) return null;

    final path = p.posix.normalize(p.posix.join(p.posix.dirname(smilPath), href));
    if (path.startsWith('/') || path.split('/').any((segment) => segment == '..')) return null;

    final source = epub.findFile(path);
    if (source == null) return null;
    final bytes = epub.readBytes(path);
    final hash = sha256.convert(bytes).toString();
    final extension = p.extension(path).isEmpty ? '.bin' : p.extension(path);
    final file = File(p.join(cacheDir.path, 'audio', '$hash$extension'));
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  String _extensionFor(String mediaType, String originalPath) {
    final ext = p.extension(originalPath);
    if (ext.isNotEmpty) return ext;
    return switch (mediaType.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => '.jpg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/svg+xml' => '.svg',
      _ => '.bin',
    };
  }
}

bool isSupportedImage(String mediaType) {
  return const {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/svg+xml',
  }.contains(mediaType.toLowerCase());
}
