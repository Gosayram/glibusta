import 'package:archive/archive.dart';

/// Shared safety limits for user-supplied ZIP-based book formats.
///
/// `archive` keeps ZIP entries lazy, but accessing [ArchiveFile.content] can
/// inflate an entry in memory. Validate metadata before any consumer reads it.
final class ArchiveSafety {
  ArchiveSafety._();

  static const int maxEntries = 1000;
  static const int maxTotalUncompressedBytes = 500 * 1024 * 1024;
  static const int maxSingleEntryBytes = 50 * 1024 * 1024;

  static void validateZip(Archive archive) {
    if (archive.files.length > maxEntries) {
      throw StateError('Archive has ${archive.files.length} entries, exceeds limit of $maxEntries');
    }

    var totalSize = 0;
    for (final entry in archive.files) {
      if (entry.isSymbolicLink || !isSafePath(entry.name)) {
        throw StateError('Unsafe entry in archive: ${entry.name}');
      }
      if (entry.size > maxSingleEntryBytes) {
        throw StateError(
          'Archive entry ${entry.name} exceeds ${maxSingleEntryBytes ~/ 1024 ~/ 1024}MB limit',
        );
      }
      totalSize += entry.size;
      if (totalSize > maxTotalUncompressedBytes) {
        throw StateError(
          'Decompressed archive exceeds ${maxTotalUncompressedBytes ~/ 1024 ~/ 1024}MB limit',
        );
      }
    }
  }

  static bool isSafePath(String path) {
    final normalized = path.replaceAll(r'\', '/');
    if (normalized.startsWith('/') || RegExp(r'^[a-zA-Z]:/').hasMatch(normalized)) {
      return false;
    }
    return !normalized.split('/').any((segment) => segment == '..');
  }
}
