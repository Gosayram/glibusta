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
import 'daos/series_dao.dart';
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
  ],
  daos: [
    BookDao,
    AuthorDao,
    SeriesDao,
    CollectionDao,
    DownloadDao,
    BookmarkDao,
    GenreDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _backupDatabase(from);
      await customStatement('PRAGMA foreign_keys = OFF');
      try {
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
  ref.onDispose(() => db.close());
  return db;
});
