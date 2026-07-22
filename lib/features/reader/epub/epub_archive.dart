import 'dart:convert';
import 'package:archive/archive.dart';

import '../../../core/formats/archive_safety.dart';

final class EpubArchive {
  EpubArchive(this.archive);
  final Archive archive;

  static Future<EpubArchive> open(String filePath) async {
    final input = InputFileStream(filePath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      ArchiveSafety.validateZip(archive);
      return EpubArchive(archive);
    } finally {
      input.closeSync();
    }
  }

  ArchiveFile? findFile(String path) {
    // ignore: use_raw_strings — r'\\' would match two backslashes, not one
    final normalized = path.replaceAll('\\', '/');
    for (final f in archive.files) {
      if (f.isFile && !f.isSymbolicLink && f.name == normalized) return f;
    }
    final decoded = Uri.decodeFull(normalized);
    for (final f in archive.files) {
      if (f.isFile && !f.isSymbolicLink && f.name == decoded) return f;
    }
    return null;
  }

  String readText(String path) {
    final file = findFile(path);
    if (file == null) throw StateError('EPUB file not found: $path');
    return utf8.decode(
      ArchiveSafety.readEntryBytes(file, maxBytes: ArchiveSafety.maxSingleEntryBytes),
      allowMalformed: true,
    );
  }

  List<int> readBytes(String path) {
    final file = findFile(path);
    if (file == null) throw StateError('EPUB file not found: $path');
    return ArchiveSafety.readEntryBytes(file, maxBytes: ArchiveSafety.maxSingleEntryBytes);
  }

  String? findFileBySuffix(String suffix) {
    for (final f in archive.files) {
      if (f.name.endsWith(suffix)) return f.name;
    }
    return null;
  }
}
