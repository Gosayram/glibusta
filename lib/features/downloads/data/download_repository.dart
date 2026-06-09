import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/platform/file_system_service.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../domain/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final fileSystem = ref.watch(fileSystemServiceProvider);
  return DownloadRepositoryImpl(db, fileSystem);
});

class DownloadRepositoryImpl implements DownloadRepository {
  final AppDatabase _db;
  final FileSystemService _fileSystem;

  DownloadRepositoryImpl(this._db, this._fileSystem);

  @override
  Stream<List<DownloadTask>> watchAllDownloads() {
    return _db.watchAllDownloads().map((List<Download> rows) {
      return rows.map(_rowToTask).toList();
    });
  }

  @override
  Future<List<DownloadTask>> getAllDownloads() async {
    final rows = await _db.getAllDownloads();
    return rows.map(_rowToTask).toList();
  }

  @override
  Future<DownloadTask?> getDownloadById(String id) async {
    final row = await _db.getDownloadById(id);
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

    final bookFile = await _fileSystem.getBookFile(bookId);
    final targetPath = bookFile.path;

    await _db.insertDownload(
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
    await _db.updateDownloadProgress(taskId, downloaded, total);
  }

  @override
  Future<void> updateStatus(String taskId, DownloadStatus status) async {
    final driftStatus = _statusToDrift(status);
    await _db.updateDownloadStatus(taskId, driftStatus);
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    await _db.updateDownloadStatus(taskId, DownloadStatusDb.canceled);
  }

  @override
  Future<void> removeDownload(String taskId) async {
    await _db.deleteDownload(taskId);
  }

  DownloadTask _rowToTask(Download row) {
    return DownloadTask(
      id: row.id,
      bookId: row.bookId,
      format: BookFormat.values.firstWhere(
        (BookFormat f) => f.name == row.format,
        orElse: () => BookFormat.fb2,
      ),
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
