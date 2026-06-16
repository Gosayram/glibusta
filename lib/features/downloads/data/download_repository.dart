import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../../shared/models/download_task.dart';
import '../../reader/data/parsers/format_detector.dart';
import '../domain/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(appFileStorageProvider);
  return DownloadRepositoryImpl(db, storage);
});

class DownloadRepositoryImpl implements DownloadRepository {
  final AppDatabase _db;
  final AppFileStorage _storage;

  DownloadRepositoryImpl(this._db, this._storage);

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

    final bookFile = await _storage.bookFile(bookId, format);
    final targetPath = bookFile.path;

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
