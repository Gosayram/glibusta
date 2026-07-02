import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../shared/models/download_task.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../domain/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DownloadRepositoryImpl(db);
});

class DownloadRepositoryImpl implements DownloadRepository {
  final AppDatabase _db;

  DownloadRepositoryImpl(this._db);

  @override
  Stream<List<DownloadTask>> watchAllDownloads() {
    return _db.downloadDao.watchAllDownloads().map((List<Download> rows) {
      return rows.map(_rowToTask).toList();
    });
  }

  @override
  Future<List<DownloadTask>> getAllDownloads() async {
    final rows = await _db.downloadDao.getAllDownloads();
    return rows.map(_rowToTask).toList();
  }

  @override
  Future<DownloadTask?> getDownloadById(String id) async {
    final row = await _db.downloadDao.getDownloadById(id);
    if (row == null) return null;
    return _rowToTask(row);
  }

  @override
  Future<DownloadTask> startDownload({
    required String bookId,
    required String bookTitle,
    required BookFormat format,
    required String sourceUrl,
  }) async {
    const uuid = Uuid();
    final taskId = uuid.v4();

    final fileName = '${_sanitizeId(bookId)}.${format.name}';
    final targetPath = '/storage/emulated/0/Download/Glibusta/$fileName';

    await _db.downloadDao.insertDownload(
      DownloadsCompanion(
        id: Value(taskId),
        bookId: Value(bookId),
        bookTitle: Value(bookTitle),
        format: Value(format.name),
        sourceUrl: Value(sourceUrl),
        targetPath: Value(targetPath),
        status: const Value(DownloadStatusDb.queued),
      ),
    );

    return DownloadTask(
      id: taskId,
      bookId: bookId,
      bookTitle: bookTitle,
      format: format,
      sourceUrl: sourceUrl,
      targetPath: targetPath,
      status: DownloadStatus.queued,
      downloadedBytes: 0,
      totalBytes: 0,
    );
  }

  @override
  Future<void> updateProgress(
    String taskId,
    int downloaded,
    int total,
  ) async {
    await _db.downloadDao.updateDownloadProgress(taskId, downloaded, total);
  }

  @override
  Future<void> updateStatus(String taskId, DownloadStatus status) async {
    final driftStatus = _statusToDrift(status);
    await _db.downloadDao.updateDownloadStatus(taskId, driftStatus);
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    await _db.downloadDao.updateDownloadStatus(taskId, DownloadStatusDb.canceled);
  }

  @override
  Future<void> removeDownload(String taskId) async {
    await _db.downloadDao.deleteDownload(taskId);
  }

  @override
  Future<void> registerInLibrary({
    required String bookId,
    required String bookTitle,
    required String format,
    required String filePath,
  }) async {
    await _db
        .into(_db.savedBooks)
        .insertOnConflictUpdate(
          SavedBooksCompanion.insert(
            id: bookId,
            title: bookTitle,
            filePath: Value(filePath),
          ),
        );
  }

  DownloadTask _rowToTask(Download row) {
    return DownloadTask(
      id: row.id,
      bookId: row.bookId,
      bookTitle: row.bookTitle,
      format: formatFromDbString(row.format),
      sourceUrl: row.sourceUrl,
      targetPath: row.targetPath,
      status: _driftToStatus(row.status),
      downloadedBytes: row.downloadedBytes,
      totalBytes: row.totalBytes,
    );
  }

  DownloadStatusDb _statusToDrift(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.queued => DownloadStatusDb.queued,
      DownloadStatus.running => DownloadStatusDb.running,
      DownloadStatus.paused => DownloadStatusDb.paused,
      DownloadStatus.completed => DownloadStatusDb.completed,
      DownloadStatus.failed => DownloadStatusDb.failed,
      DownloadStatus.canceled => DownloadStatusDb.canceled,
    };
  }

  DownloadStatus _driftToStatus(DownloadStatusDb status) {
    return switch (status) {
      DownloadStatusDb.queued => DownloadStatus.queued,
      DownloadStatusDb.running => DownloadStatus.running,
      DownloadStatusDb.paused => DownloadStatus.paused,
      DownloadStatusDb.completed => DownloadStatus.completed,
      DownloadStatusDb.failed => DownloadStatus.failed,
      DownloadStatusDb.canceled => DownloadStatus.canceled,
    };
  }
}

String _sanitizeId(String id) {
  var s = id.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  while (s.startsWith('.')) {
    s = s.substring(1);
  }
  s = s.trim();
  if (s.isEmpty) s = 'unnamed';
  if (s.length > 200) s = s.substring(0, 200);
  return s;
}
