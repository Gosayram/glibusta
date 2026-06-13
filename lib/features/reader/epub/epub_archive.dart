import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

final class EpubArchive {
  EpubArchive(this.archive);
  final Archive archive;

  static Future<EpubArchive> open(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return EpubArchive(archive);
  }

  ArchiveFile? findFile(String path) {
    // ignore: use_raw_strings — r'\\' would match two backslashes, not one
    final normalized = path.replaceAll('\\', '/');
    for (final f in archive.files) {
      if (f.isFile && f.name == normalized) return f;
    }
    final decoded = Uri.decodeFull(normalized);
    for (final f in archive.files) {
      if (f.isFile && f.name == decoded) return f;
    }
    return null;
  }

  String readText(String path) {
    final file = findFile(path);
    if (file == null) throw StateError('EPUB file not found: $path');
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  List<int> readBytes(String path) {
    final file = findFile(path);
    if (file == null) throw StateError('EPUB file not found: $path');
    return List<int>.from(file.content as List<int>);
  }

  String? findFileBySuffix(String suffix) {
    for (final f in archive.files) {
      if (f.name.endsWith(suffix)) return f.name;
    }
    return null;
  }
}
