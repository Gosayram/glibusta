import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../logging/app_logger.dart';
import 'app_database.dart';

class RecoveryBackupInfo {
  const RecoveryBackupInfo({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}

class LostDataReport {
  const LostDataReport({
    required this.bookmarksLost,
    required this.highlightsLost,
    required this.notesLost,
    required this.quotesLost,
    required this.readingProgressLost,
  });

  final int bookmarksLost;
  final int highlightsLost;
  final int notesLost;
  final int quotesLost;
  final int readingProgressLost;

  bool get hasLoss =>
      bookmarksLost > 0 ||
      highlightsLost > 0 ||
      notesLost > 0 ||
      quotesLost > 0 ||
      readingProgressLost > 0;
}

class DatabaseRecovery {
  DatabaseRecovery({required this.db, String? databasePath}) : _databasePath = databasePath;

  final AppDatabase db;
  final String? _databasePath;
  final _logger = AppLogger();

  static const _backupSuffix = '.recovery_backup';
  static const _backupDir = 'db_backups';

  Future<String> get _dbPath async {
    if (_databasePath != null) return _databasePath;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'glibusta', 'glibusta.sqlite');
  }

  Future<Directory> get _backupDirectory async {
    final dbPath = await _dbPath;
    final backupDir = Directory(p.join(p.dirname(dbPath), _backupDir));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<String> createDatabaseBackup() async {
    final dbPath = await _dbPath;
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('Database file does not exist: $dbPath');
    }

    await db.checkpointWal();

    final backupDir = await _backupDirectory;
    final timestamp = _formatTimestamp(DateTime.now());
    final backupPath = p.join(backupDir.path, 'glibusta_$timestamp$_backupSuffix');

    await dbFile.copy(backupPath);

    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      await walFile.copy('$backupPath-wal');
    }

    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.copy('$backupPath-shm');
    }

    _logger.info('Database backup created: $backupPath', name: 'DatabaseRecovery');
    return backupPath;
  }

  Future<bool> validateBackup(String backupPath) async {
    final file = File(backupPath);
    if (!await file.exists()) return false;

    try {
      final db = sqlite.sqlite3.open(file.path);
      try {
        db.select('SELECT count(*) FROM sqlite_master');
        return true;
      } finally {
        db.close();
      }
    } on Object catch (e) {
      _logger.warning('Backup validation failed: $e', name: 'DatabaseRecovery');
      return false;
    }
  }

  Future<void> recoverFromBackup(String backupPath) async {
    final isValid = await validateBackup(backupPath);
    if (!isValid) {
      throw StateError('Backup file is not a valid SQLite database: $backupPath');
    }

    final dbPath = await _dbPath;
    final dbFile = File(dbPath);
    await db.close();

    final backupFile = File(backupPath);
    await backupFile.copy(dbFile.path);

    final walBackup = File('$backupPath-wal');
    if (await walBackup.exists()) {
      await walBackup.copy('${dbFile.path}-wal');
    }

    final shmBackup = File('$backupPath-shm');
    if (await shmBackup.exists()) {
      await shmBackup.copy('${dbFile.path}-shm');
    }

    _logger.info('Database recovered from: $backupPath', name: 'DatabaseRecovery');
  }

  Future<List<RecoveryBackupInfo>> listBackups() async {
    final backupDir = await _backupDirectory;
    if (!await backupDir.exists()) return [];

    final backups = <RecoveryBackupInfo>[];
    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith(_backupSuffix)) {
        final stat = await entity.stat();
        backups.add(
          RecoveryBackupInfo(
            path: entity.path,
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<LostDataReport> reportLostData(String backupPath) async {
    final backupDb = AppDatabase(NativeDatabase(File(backupPath)));
    try {
      final backupBookmarks = await backupDb.select(backupDb.bookmarks).get();
      final backupHighlights = await backupDb.select(backupDb.textHighlights).get();
      final backupNotes = await backupDb.select(backupDb.notes).get();
      final backupQuotes = await backupDb.select(backupDb.quotes).get();
      final backupProgress = await backupDb.select(backupDb.readingProgress).get();

      final currentBookmarks = await db.select(db.bookmarks).get();
      final currentHighlights = await db.select(db.textHighlights).get();
      final currentNotes = await db.select(db.notes).get();
      final currentQuotes = await db.select(db.quotes).get();
      final currentProgress = await db.select(db.readingProgress).get();

      final currentBookmarkIds = currentBookmarks.map((b) => b.id).toSet();
      final currentHighlightIds = currentHighlights.map((h) => h.id).toSet();
      final currentNoteIds = currentNotes.map((n) => n.id).toSet();
      final currentQuoteIds = currentQuotes.map((q) => q.id).toSet();
      final currentProgressIds = currentProgress.map((p) => p.bookId).toSet();

      return LostDataReport(
        bookmarksLost: backupBookmarks.where((b) => !currentBookmarkIds.contains(b.id)).length,
        highlightsLost: backupHighlights.where((h) => !currentHighlightIds.contains(h.id)).length,
        notesLost: backupNotes.where((n) => !currentNoteIds.contains(n.id)).length,
        quotesLost: backupQuotes.where((q) => !currentQuoteIds.contains(q.id)).length,
        readingProgressLost: backupProgress
            .where((p) => !currentProgressIds.contains(p.bookId))
            .length,
      );
    } finally {
      await backupDb.close();
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}_'
        '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
