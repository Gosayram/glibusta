import 'dart:math';
import 'dart:typed_data';

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

  /// Decompress [entry] into a bounded buffer and verify that the ZIP
  /// central-directory size agrees with the bytes actually produced.
  ///
  /// [ArchiveFile.size] is archive metadata, not a trustworthy allocation
  /// limit. A malformed ZIP can declare a small entry and emit more bytes
  /// while being decompressed, so consumers must use this instead of
  /// [ArchiveFile.content] for untrusted entries.
  static Uint8List readEntryBytes(ArchiveFile entry, {required int maxBytes}) {
    if (entry.size > maxBytes) {
      throw StateError(
        'Archive entry ${entry.name} exceeds ${maxBytes ~/ 1024 ~/ 1024}MB limit',
      );
    }

    final output = _BoundedOutputStream(maxBytes);
    entry.decompress(output);
    if (output.length != entry.size) {
      throw StateError(
        'Archive entry ${entry.name} declared ${entry.size} bytes but extracted '
        '${output.length} bytes',
      );
    }
    return output.toBytes();
  }

  static bool isSafePath(String path) {
    final normalized = path.replaceAll(r'\', '/');
    if (normalized.startsWith('/') || RegExp(r'^[a-zA-Z]:/').hasMatch(normalized)) {
      return false;
    }
    return !normalized.split('/').any((segment) => segment == '..');
  }
}

/// An [OutputStream] which stops decompression before an entry can grow past
/// its caller-provided limit. `archive` feeds ZIP DEFLATE output to this stream
/// incrementally on Dart IO, so the limit is enforced during extraction.
final class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this._maxBytes) : super(byteOrder: ByteOrder.littleEndian);

  final int _maxBytes;
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  @override
  int length = 0;

  @override
  void clear() {
    _bytes.clear();
    length = 0;
  }

  @override
  void flush() {}

  @override
  Uint8List subset(int start, [int? end]) {
    final bytes = toBytes();
    return Uint8List.sublistView(bytes, start, end);
  }

  @override
  void writeByte(int value) {
    _ensureCapacity(1);
    _bytes.addByte(value);
    length++;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final byteCount = length ?? bytes.length;
    if (byteCount < 0 || byteCount > bytes.length) {
      throw ArgumentError.value(length, 'length');
    }
    _ensureCapacity(byteCount);
    _bytes.add(byteCount == bytes.length ? bytes : bytes.sublist(0, byteCount));
    this.length += byteCount;
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final byteCount = min(stream.length, 8192);
      writeBytes(stream.readBytes(byteCount).toUint8List());
    }
  }

  Uint8List toBytes() => _bytes.toBytes();

  void _ensureCapacity(int incomingBytes) {
    if (incomingBytes > _maxBytes - length) {
      throw StateError(
        'Archive entry exceeds ${_maxBytes ~/ 1024 ~/ 1024}MB limit during extraction',
      );
    }
  }
}
