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
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _backupDatabase(from); // throws on failure — aborts migration
      await customStatement('PRAGMA foreign_keys = OFF');

      // Ponytail: SQLite DDL auto-commits each statement, so the enclosing
      // transaction cannot roll back partially-applied schema changes.
      // Wrapping addColumn in a try/catch makes the migration idempotent —
      // if a previous run partially committed, retries won't crash on
      // "duplicate column name".
      // ignore: strict_raw_type
      Future<void> addCol(TableInfo table, GeneratedColumn column) async {
        try {
          await m.addColumn(table, column);
        } on Object catch (e) {
          if (!e.toString().contains('duplicate column')) rethrow;
        }
      }

      try {
        if (from > to) {
          await _handleDowngrade(m, from, to);
          return;
        }
        await transaction(() async {
          if (from < 2) {
            await addCol(savedBooks, savedBooks.contentHash);
            await addCol(savedBooks, savedBooks.fileSize);
          }
          if (from < 3) {
            await addCol(savedBooks, savedBooks.filePath);
          }
          if (from < 4) {
            await m.createTable(readingSessions);
          }
          if (from < 5) {
            await addCol(readingProgress, readingProgress.chapterIndex);
            await addCol(readingProgress, readingProgress.paragraphIndex);
            await addCol(readingProgress, readingProgress.localOffset);
            await addCol(readingProgress, readingProgress.progressPercent);
            await addCol(readingProgress, readingProgress.updatedAt);
          }
          if (from < 6) {
            await addCol(savedBooks, savedBooks.readingStatus);
          }
          if (from < 7) {
            await addCol(savedBooks, savedBooks.detectedEncoding);
            await addCol(savedBooks, savedBooks.encodingConfidence);
            await addCol(savedBooks, savedBooks.encodingSource);
            await addCol(savedBooks, savedBooks.userForcedEncoding);
          }
          if (from < 8) {
            await addCol(savedBooks, savedBooks.storageMode);
            await addCol(savedBooks, savedBooks.externalUri);
          }
          if (from < 9) {
            await addCol(savedBooks, savedBooks.coverPath);
            await addCol(savedBooks, savedBooks.coverStatus);
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
            await addCol(readingProgress, readingProgress.chapterId);
            await addCol(readingProgress, readingProgress.textOffset);
          }
          if (from < 15) {
            await addCol(textHighlights, textHighlights.decoration);
          }
          if (from < 16) {
            await addCol(savedBooks, savedBooks.deletedAt);
          }
          if (from < 17) {
            await addCol(readingTime, readingTime.pagesRead);
          }
          if (from < 18) {
            await addCol(readingTime, readingTime.wpm);
            await addCol(readingTime, readingTime.wpmSessionCount);
          }
          if (from < 19) {
            await addCol(bookmarks, bookmarks.highlightStyle);
            await addCol(bookmarks, bookmarks.highlightColor);
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
    final dbFile = File(await _databasePath);
    if (!await dbFile.exists()) {
      await _cleanupOldBackups();
      return;
    }
    final dbPath = await _databasePath;
    final backupFile = File('$dbPath.v${previousVersion ?? 0}.bak');
    await dbFile.copy(backupFile.path);
    for (final ext in ['-wal', '-shm']) {
      final src = File('$dbPath$ext');
      if (await src.exists()) {
        await src.copy('${backupFile.path}$ext');
      }
    }
    await _cleanupOldBackups();
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
      int extractVersion(String path) {
        final m = RegExp(r'\.v(\d+)\.bak$').firstMatch(path);
        return m != null ? int.parse(m.group(1)!) : 0;
      }

      bakFiles.sort((a, b) => extractVersion(a.path).compareTo(extractVersion(b.path)));
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
    unawaited(db.checkpointWal().then((_) => db.close()));
  });
  return db;
});
