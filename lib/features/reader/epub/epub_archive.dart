import 'dart:convert';
import 'package:archive/archive.dart';

const int _maxArchiveEntries = 1000;
const int _maxDecompressedBytes = 500 * 1024 * 1024;

final class EpubArchive {
  EpubArchive(this.archive);
  final Archive archive;

  static Future<EpubArchive> open(String filePath) async {
    final input = InputFileStream(filePath);
    final archive = ZipDecoder().decodeStream(input);
    _validateArchive(archive);
    return EpubArchive(archive);
  }

  static void _validateArchive(Archive archive) {
    if (archive.files.length > _maxArchiveEntries) {
      throw StateError(
        'Archive has ${archive.files.length} entries, exceeds limit of $_maxArchiveEntries',
      );
    }
    var totalSize = 0;
    for (final f in archive.files) {
      if (_hasZipSlip(f.name)) {
        throw StateError('Unsafe path in archive: ${f.name}');
      }
      totalSize += f.size;
      if (totalSize > _maxDecompressedBytes) {
        throw StateError(
          'Decompressed archive exceeds ${_maxDecompressedBytes ~/ 1024 ~/ 1024}MB limit',
        );
      }
    }
  }

  static bool _hasZipSlip(String name) {
    if (name.startsWith('/')) return true;
    if (name.contains('..')) return true;
    return false;
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
