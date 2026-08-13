import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/formats/archive_safety.dart';

void main() {
  ArchiveFile falseSmallZipEntry() {
    final archive = Archive()..addFile(ArchiveFile.noCompress('page.png', 2, [1, 2]));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    const centralDirectorySignature = [0x50, 0x4b, 0x01, 0x02];
    var centralDirectory = -1;
    for (var index = 0; index + centralDirectorySignature.length <= bytes.length; index++) {
      var matches = true;
      for (var offset = 0; offset < centralDirectorySignature.length; offset++) {
        if (bytes[index + offset] != centralDirectorySignature[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        centralDirectory = index;
        break;
      }
    }
    expect(centralDirectory, isNonNegative);

    // Central directory's uncompressed-size field is at byte 24. The raw
    // stored payload remains two bytes, reproducing a metadata-only lie.
    ByteData.sublistView(bytes).setUint32(centralDirectory + 24, 1, Endian.little);
    return ZipDecoder().decodeBytes(bytes).files.single;
  }

  test('accepts ordinary relative file entries', () {
    final archive = Archive()..addFile(ArchiveFile.bytes('OEBPS/chapter.xhtml', [1, 2, 3]));

    expect(() => ArchiveSafety.validateZip(archive), returnsNormally);
  });

  test('rejects path traversal, absolute paths, and symbolic links', () {
    final unsafePaths = ['../book.xhtml', '/etc/passwd', r'C:\Windows\book.xhtml'];

    for (final path in unsafePaths) {
      final archive = Archive()..addFile(ArchiveFile.bytes(path, [1]));
      expect(() => ArchiveSafety.validateZip(archive), throwsStateError);
    }

    final symlinkArchive = Archive()..addFile(ArchiveFile.symlink('cover', '../../secret'));
    expect(() => ArchiveSafety.validateZip(symlinkArchive), throwsStateError);
  });

  test('rejects an entry above the in-memory extraction limit', () {
    final archive = Archive()
      ..addFile(ArchiveFile('large.bin', ArchiveSafety.maxSingleEntryBytes + 1, const []));

    expect(() => ArchiveSafety.validateZip(archive), throwsStateError);
  });

  test('rejects an entry whose decompressed bytes exceed declared ZIP metadata', () {
    final entry = falseSmallZipEntry();

    expect(
      () => ArchiveSafety.readEntryBytes(entry, maxBytes: 2),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('declared 1 bytes but extracted 2 bytes'),
        ),
      ),
    );
  });

  test('stops extraction when streamed bytes exceed the caller limit', () {
    final entry = falseSmallZipEntry();

    expect(
      () => ArchiveSafety.readEntryBytes(entry, maxBytes: 1),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('during extraction'),
        ),
      ),
    );
  });
}
