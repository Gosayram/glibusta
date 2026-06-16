import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../services/file_integrity_service.dart';

enum RecoveryStatus { healthy, degraded, critical }

class RecoveryReport {
  const RecoveryReport({
    required this.status,
    required this.databaseOk,
    required this.storageOk,
    required this.indexOk,
    required this.lastError,
    required this.checkedAt,
    this.repairedCount = 0,
    this.corruptedBooks = const [],
    this.orphanFiles = const [],
  });

  final RecoveryStatus status;
  final bool databaseOk;
  final bool storageOk;
  final bool indexOk;
  final String? lastError;
  final DateTime checkedAt;
  final int repairedCount;
  final List<String> corruptedBooks;
  final List<String> orphanFiles;
}

class RecoveryMode {
  RecoveryMode(this._db, this._logger, this._integrityService);
  final AppDatabase _db;
  final AppLogger _logger;
  final FileIntegrityService _integrityService;

  static const _recoveryKey = 'last_recovery_status';
  static const _crashCountKey = 'consecutive_crash_count';

  Future<bool> shouldEnterRecoveryMode() async {
    final prefs = await SharedPreferences.getInstance();
    final crashCount = prefs.getInt(_crashCountKey) ?? 0;
    return crashCount >= 3;
  }

  Future<void> recordCrash() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_crashCountKey) ?? 0;
    await prefs.setInt(_crashCountKey, count + 1);
  }

  Future<void> clearCrashCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_crashCountKey);
  }

  Future<RecoveryReport> runDiagnostics() async {
    _logger.info('Running recovery diagnostics...', name: 'Recovery');

    bool dbOk = true;
    bool storageOk = true;
    bool indexOk = true;
    String? lastError;
    final corruptedBooks = <String>[];
    final orphanFiles = <String>[];

    // Check database
    try {
      await _db.customSelect('SELECT 1').get();
    } on Object catch (e) {
      dbOk = false;
      lastError = 'Database error: $e';
      _logger.severe('DB check failed: $e', name: 'Recovery');
    }

    // Check storage
    try {
      final appDir = await getApplicationSupportDirectory();
      if (!await appDir.exists()) {
        storageOk = false;
        lastError = 'App directory missing';
      }
    } on Object catch (e) {
      storageOk = false;
      lastError = 'Storage error: $e';
    }

    // Check book integrity
    try {
      final corrupted = await _integrityService.verifyAll();
      corruptedBooks.addAll(corrupted);
      if (corrupted.isNotEmpty) {
        indexOk = false;
        lastError = 'Found ${corrupted.length} corrupted books';
      }
    } on Object catch (e) {
      indexOk = false;
      lastError = 'Index check error: $e';
    }

    // Check orphan files
    try {
      orphanFiles.addAll(await _findOrphanFiles());
    } on Object catch (e) {
      _logger.warning('Orphan check failed: $e', name: 'Recovery');
    }

    final status = _determineStatus(dbOk, storageOk, indexOk);

    final report = RecoveryReport(
      status: status,
      databaseOk: dbOk,
      storageOk: storageOk,
      indexOk: indexOk,
      lastError: lastError,
      checkedAt: DateTime.now(),
      corruptedBooks: corruptedBooks,
      orphanFiles: orphanFiles,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recoveryKey, status.name);

    return report;
  }

  Future<void> enterSafeMode() async {
    _logger.info('Entering safe mode...', name: 'Recovery');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safe_mode', true);
  }

  Future<void> exitSafeMode() async {
    _logger.info('Exiting safe mode', name: 'Recovery');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safe_mode', false);
  }

  Future<bool> isInSafeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('safe_mode') ?? false;
  }

  Future<int> rebuildIndex() async {
    _logger.info('Rebuilding index...', name: 'Recovery');
    int count = 0;
    try {
      final books = await _db.select(_db.savedBooks).get();
      final validIds = <String>{};
      for (final book in books) {
        if (book.filePath.isNotEmpty && await File(book.filePath).exists()) {
          validIds.add(book.id);
        }
      }
      final staleIds = books.where((b) => !validIds.contains(b.id)).map((b) => b.id).toList();
      if (staleIds.isNotEmpty) {
        await _db.batch((batch) {
          batch.deleteWhere(_db.savedBooks, (t) => t.id.isIn(staleIds));
        });
        _logger.info('Removed ${staleIds.length} stale entries', name: 'Recovery');
      }
      count = validIds.length;
      _logger.info('Index rebuilt: $count valid books', name: 'Recovery');
    } on Object catch (e) {
      _logger.severe('Index rebuild failed: $e', name: 'Recovery');
    }
    return count;
  }

  Future<void> repairDatabase() async {
    _logger.info('Repairing database...', name: 'Recovery');
    try {
      await _db.customStatement('VACUUM');
      _logger.info('Database repair complete', name: 'Recovery');
    } on Object catch (e) {
      _logger.severe('DB repair failed: $e', name: 'Recovery');
    }
  }

  Future<List<String>> _findOrphanFiles() async {
    final orphans = <String>[];
    try {
      final books = await _db.select(_db.savedBooks).get();
      final dbPaths = books.map((b) => b.filePath).toSet();

      final appDir = await getApplicationSupportDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (await booksDir.exists()) {
        await for (final entity in booksDir.list(recursive: true)) {
          if (entity is File && !dbPaths.contains(entity.path)) {
            orphans.add(entity.path);
          }
        }
      }
    } on Object catch (_) {}
    return orphans;
  }

  RecoveryStatus _determineStatus(bool db, bool storage, bool index) {
    if (!db) return RecoveryStatus.critical;
    if (!storage) return RecoveryStatus.critical;
    if (!index) return RecoveryStatus.degraded;
    return RecoveryStatus.healthy;
  }

  Future<String?> getLastRecoveryStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recoveryKey);
  }
}

// --- Riverpod providers ---

final recoveryModeProvider = Provider<RecoveryMode>((ref) {
  throw UnimplementedError('Override in main');
});

final recoveryReportProvider = FutureProvider<RecoveryReport>((ref) async {
  final recovery = ref.watch(recoveryModeProvider);
  return recovery.runDiagnostics();
});
