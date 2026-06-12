import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'epub_archive.dart';
import 'epub_models.dart';

final class EpubImageStore {
  EpubImageStore(this.cacheDir);
  final Directory cacheDir;

  Future<String> saveImage({required EpubArchive epub, required EpubResource resource}) async {
    await cacheDir.create(recursive: true);
    final bytes = epub.readBytes(resource.fullPath);
    final hash = sha256.convert(bytes).toString();
    final extension = _extensionFor(resource.mediaType, resource.fullPath);
    final file = File(p.join(cacheDir.path, '$hash$extension'));
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
