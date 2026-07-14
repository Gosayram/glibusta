import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/formats/archive_safety.dart';

void main() {
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
}
