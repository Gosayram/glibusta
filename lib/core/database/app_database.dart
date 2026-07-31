import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import 'converters.dart';
import 'daos/author_dao.dart';
import 'daos/book_dao.dart';
import 'daos/bookmark_dao.dart';
import 'daos/collection_dao.dart';
import 'daos/download_dao.dart';
import 'daos/genre_dao.dart';
import 'daos/highlight_dao.dart';
import 'daos/per_book_settings_dao.dart';
import 'daos/reading_time_dao.dart';
import 'daos/series_dao.dart';
import 'daos/tag_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SavedBooks,
    Authors,
    Series,
    BookSeries,
    Genres,
    Downloads,
    ReadingProgress,
    Bookmarks,
    Notes,
    Quotes,
    SearchHistory,
    Collections,
    BookCollections,
    ReadingSessions,
    PerBookSettings,
    Tags,
    BookTags,
    ReadingTime,
    TextHighlights,
  ],
  daos: [
    BookDao,
    DownloadDao,
    CollectionDao,
    BookmarkDao,
    GenreDao,
    PerBookSettingsDao,
    TagDao,
    ReadingTimeDao,
    AuthorDao,
    SeriesDao,
    HighlightDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 17;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _backupDatabase(from);
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        if (from > to) {
          await _handleDowngrade(m, from, to);
          return;
        }
        await transaction(() async {
          if (from < 2) {
            await m.addColumn(savedBooks, savedBooks.contentHash);
            await m.addColumn(savedBooks, savedBooks.fileSize);
          }
          if (from < 3) {
            await m.addColumn(savedBooks, savedBooks.filePath);
          }
          if (from < 4) {
            await m.createTable(readingSessions);
          }
          if (from < 5) {
            await m.addColumn(readingProgress, readingProgress.chapterIndex);
            await m.addColumn(readingProgress, readingProgress.paragraphIndex);
            await m.addColumn(readingProgress, readingProgress.localOffset);
            await m.addColumn(readingProgress, readingProgress.progressPercent);
            await m.addColumn(readingProgress, readingProgress.updatedAt);
          }
          if (from < 6) {
            await m.addColumn(savedBooks, savedBooks.readingStatus);
          }
          if (from < 7) {
            await m.addColumn(savedBooks, savedBooks.detectedEncoding);
            await m.addColumn(savedBooks, savedBooks.encodingConfidence);
            await m.addColumn(savedBooks, savedBooks.encodingSource);
            await m.addColumn(savedBooks, savedBooks.userForcedEncoding);
          }
          if (from < 8) {
            await m.addColumn(savedBooks, savedBooks.storageMode);
            await m.addColumn(savedBooks, savedBooks.externalUri);
          }
          if (from < 9) {
            await m.addColumn(savedBooks, savedBooks.coverPath);
            await m.addColumn(savedBooks, savedBooks.coverStatus);
          }
          if (from < 10) {
            await m.createTable(perBookSettings);
          }
          if (from < 11) {
            await m.createTable(tags);
            await m.createTable(bookTags);
          }
          if (from < 12) {
            await m.createTable(readingTime);
          }
          if (from < 13) {
            await m.createTable(textHighlights);
          }
          if (from < 14) {
            await m.addColumn(readingProgress, readingProgress.chapterId);
            await m.addColumn(readingProgress, readingProgress.textOffset);
          }
          if (from < 15) {
            await m.addColumn(textHighlights, textHighlights.decoration);
          }
          if (from < 16) {
            await m.addColumn(savedBooks, savedBooks.deletedAt);
          }
          if (from < 17) {
            await m.addColumn(readingTime, readingTime.pagesRead);
          }
        });
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA cache_size = -8000');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA temp_store = MEMORY');
    },
  );

  Future<void> _backupDatabase(int? previousVersion) async {
    try {
      final dbFile = File(await _databasePath);
      if (await dbFile.exists()) {
        final backupFile = File(
          '${await _databasePath}.v${previousVersion ?? 0}.bak',
        );
        await dbFile.copy(backupFile.path);
      }
      await _cleanupOldBackups();
    } on Object catch (e) {
      AppLogger().warning('Database backup failed: $e', name: 'Database', error: e);
    }
  }

  Future<void> _handleDowngrade(Migrator m, int from, int to) async {
    AppLogger().warning(
      'Database downgraded from $from to $to — recreating all tables',
      name: 'Database',
    );
    final reversedEntities = m.database.allSchemaEntities.toList().reversed;
    await transaction(() async {
      for (final entity in reversedEntities) {
        await m.drop(entity);
      }
      await m.createAll();
    });
  }

  static const int _maxBackups = 3;

  Future<void> _cleanupOldBackups() async {
    try {
      final dbDir = Directory(p.dirname(await _databasePath));
      if (!await dbDir.exists()) return;
      final bakFiles = await dbDir
          .list()
          .where((e) => e.path.endsWith('.bak'))
          .map((e) => File(e.path))
          .toList();
      if (bakFiles.length <= _maxBackups) return;
      bakFiles.sort((a, b) => a.path.compareTo(b.path));
      for (var i = 0; i < bakFiles.length - _maxBackups; i++) {
        await bakFiles[i].delete();
      }
    } on Object catch (_) {}
  }

  static Future<String> get _databasePath async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'glibusta', 'glibusta.sqlite');
  }

  Future<File> prepareUploadSnapshot() async {
    final dbPath = await _databasePath;
    final snapshotFile = File('$dbPath.upload');
    try {
      await customStatement('VACUUM INTO ?', [snapshotFile.path]);
    } on Object catch (e) {
      AppLogger().warning(
        'VACUUM INTO failed, falling back to copy: $e',
        name: 'Database',
        error: e,
      );
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final dbFile = File(dbPath);
      await dbFile.copy(snapshotFile.path);
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.copy('${snapshotFile.path}-wal');
      }
      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.copy('${snapshotFile.path}-shm');
      }
    }
    return snapshotFile;
  }

  Future<void> deleteUploadSnapshot() async {
    final dbPath = await _databasePath;
    final snapshotPath = '$dbPath.upload';
    for (final path in [snapshotPath, '$snapshotPath-wal', '$snapshotPath-shm']) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  Future<void> fixDatabaseHeader() async {
    final dbPath = await _databasePath;
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) return;

    try {
      final bytes = await dbFile.readAsBytes();
      if (bytes.length < 20) return;

      const walMagicOffset = 18;
      final byte0 = bytes[0];
      final byte1 = bytes[1];

      if (byte0 == 0x37 && byte1 == 0x0f && bytes.length > walMagicOffset + 2) {
        final walByte0 = bytes[walMagicOffset];
        final walByte1 = bytes[walMagicOffset + 1];

        if (walByte0 == 0x37 && walByte1 == 0x0f) {
          AppLogger().info(
            'Patching WAL header for legacy compatibility',
            name: 'Database',
          );
          final patched = Uint8List.fromList(bytes);
          patched[walMagicOffset] = 0x37;
          patched[walMagicOffset + 1] = 0x0f;
          patched[walMagicOffset + 2] = 0x10;
          patched[walMagicOffset + 3] = 0x20;
          await dbFile.writeAsBytes(patched);
        }
      }
    } on Object catch (e) {
      AppLogger().warning(
        'Failed to fix database header: $e',
        name: 'Database',
        error: e,
      );
    }
  }

  Future<void> checkpointWal() async {
    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } on Object catch (e) {
      AppLogger().warning(
        'WAL checkpoint failed: $e',
        name: 'Database',
        error: e,
      );
    }
  }

  Future<DateTime?> getLatestModTime() async {
    final dbPath = await _databasePath;
    DateTime? latest;
    for (final ext in ['', '-wal']) {
      final f = File('$dbPath$ext');
      if (await f.exists()) {
        final stat = await f.stat();
        if (latest == null || stat.modified.isAfter(latest)) {
          latest = stat.modified;
        }
      }
    }
    return latest;
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'glibusta',
    native: DriftNativeOptions(
      shareAcrossIsolates: true,
      databaseDirectory: () async {
        final dir = await getApplicationDocumentsDirectory();
        return Directory(p.join(dir.path, 'glibusta'));
      },
    ),
  );
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    unawaited(db.checkpointWal());
    unawaited(db.close());
  });
  return db;
});
