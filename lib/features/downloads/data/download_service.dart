import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart';
import '../../../core/platform/app_file_storage.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final database = ref.watch(databaseProvider);
  return DownloadService(database);
});

class DownloadService {
  final AppDatabase _database;
  final AppFileStorage _storage;

  DownloadService(this._database) : _storage = AppFileStorageImpl();

  Future<String> get booksDirectory async {
    final dir = await _storage.booksDir();
    return dir.path;
  }

  Future<void> downloadBook({
    required String bookId,
    required String bookTitle,
    required String format,
    required String sourceUrl,
  }) async {
    final booksDir = await booksDirectory;
    final fileName = '$bookId.$format';
    final targetPath = '$booksDir/$fileName';

    await _database
        .into(_database.downloads)
        .insert(
          DownloadsCompanion.insert(
            id: bookId,
            bookId: bookId,
            bookTitle: Value(bookTitle),
            format: format,
            sourceUrl: sourceUrl,
            targetPath: Value(targetPath),
            status: DownloadStatusDb.queued,
          ),
        );

    final task = DownloadTask(
      url: sourceUrl,
      filename: fileName,
      directory: booksDir,
      updates: Updates.statusAndProgress,
      metaData: 'bookId=$bookId',
    );

    final result = await FileDownloader().download(
      task,
      onProgress: (progress) {
        unawaited(_updateProgress(bookId, progress));
      },
      onStatus: (status) {
        unawaited(_updateStatus(bookId, status));
      },
    );

    if (result.status == TaskStatus.complete) {
      await (_database.update(_database.downloads)..where((d) => d.id.equals(bookId))).write(
        DownloadsCompanion(
          status: const Value(DownloadStatusDb.completed),
          completedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _updateProgress(String downloadId, double progress) async {
    await (_database.update(_database.downloads)..where((d) => d.id.equals(downloadId))).write(
      DownloadsCompanion(
        downloadedBytes: Value((progress * 1000000).toInt()),
        totalBytes: const Value(1000000),
      ),
    );
  }

  Future<void> _updateStatus(String downloadId, TaskStatus status) async {
    DownloadStatusDb dbStatus;
    switch (status) {
      case TaskStatus.running:
        dbStatus = DownloadStatusDb.running;
        break;
      case TaskStatus.paused:
        dbStatus = DownloadStatusDb.paused;
        break;
      case TaskStatus.failed:
        dbStatus = DownloadStatusDb.failed;
        break;
      case TaskStatus.canceled:
        dbStatus = DownloadStatusDb.canceled;
        break;
      case TaskStatus.complete:
        dbStatus = DownloadStatusDb.completed;
        break;
      default:
        dbStatus = DownloadStatusDb.queued;
    }

    await (_database.update(_database.downloads)..where((d) => d.id.equals(downloadId))).write(
      DownloadsCompanion(
        status: Value(dbStatus),
      ),
    );
  }

  /// Finds the [DownloadTask] whose [Task.metaData] matches
  /// `'bookId=$bookId'`. Returns `null` if the task is no longer active.
  Future<DownloadTask?> _findTaskByBookId(String bookId) async {
    final allTasks = await FileDownloader().allTasks();
    final needle = 'bookId=$bookId';
    for (final t in allTasks) {
      if (t is DownloadTask && t.metaData == needle) return t;
    }
    return null;
  }

  Future<void> pauseDownload(String downloadId) async {
    final task = await _findTaskByBookId(downloadId);
    if (task != null) {
      await FileDownloader().pause(task);
    }
    await (_database.update(_database.downloads)..where((d) => d.id.equals(downloadId))).write(
      const DownloadsCompanion(
        status: Value(DownloadStatusDb.paused),
      ),
    );
  }

  Future<void> resumeDownload(String downloadId) async {
    final task = await _findTaskByBookId(downloadId);
    if (task != null) {
      await FileDownloader().resume(task);
    }
    await (_database.update(_database.downloads)..where((d) => d.id.equals(downloadId))).write(
      const DownloadsCompanion(
        status: Value(DownloadStatusDb.running),
      ),
    );
  }

  Future<void> cancelDownload(String downloadId) async {
    final task = await _findTaskByBookId(downloadId);
    if (task != null) {
      await FileDownloader().cancelTaskWithId(task.taskId);
    }
    await (_database.update(_database.downloads)..where((d) => d.id.equals(downloadId))).write(
      const DownloadsCompanion(
        status: Value(DownloadStatusDb.canceled),
      ),
    );
  }

  Future<void> removeDownload(String downloadId) async {
    final download = await (_database.select(
      _database.downloads,
    )..where((d) => d.id.equals(downloadId))).getSingleOrNull();

    if (download?.targetPath != null) {
      final file = File(download!.targetPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await (_database.delete(_database.downloads)..where((d) => d.id.equals(downloadId))).go();
  }

  Stream<List<Download>> get activeDownloadsStream {
    return (_database.select(_database.downloads)
          ..where(
            (d) => d.status.isNotIn([
              DownloadStatusDb.completed.index,
              DownloadStatusDb.failed.index,
              DownloadStatusDb.canceled.index,
            ]),
          )
          ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
        .watch();
  }

  Future<List<Download>> getAllDownloads() async {
    return (_database.select(
      _database.downloads,
    )..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).get();
  }
}
