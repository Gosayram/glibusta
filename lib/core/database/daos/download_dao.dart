import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'download_dao.g.dart';

@DriftAccessor(tables: [Downloads])
class DownloadDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadDaoMixin {
  DownloadDao(super.db);

  Future<List<Download>> getAllDownloads() async =>
      (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<Download>> watchAllDownloads() =>
      (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<Download?> getDownloadById(String id) async =>
      (select(downloads)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertDownload(DownloadsCompanion entry) =>
      into(downloads).insertOnConflictUpdate(entry);

  Future<int> updateDownloadStatus(String id, DownloadStatusDb status) =>
      (update(downloads)..where((t) => t.id.equals(id))).write(
        DownloadsCompanion(status: Value(status)),
      );

  Future<int> updateDownloadProgress(String id, int downloaded, int total) =>
      (update(downloads)..where((t) => t.id.equals(id))).write(
        DownloadsCompanion(
          downloadedBytes: Value(downloaded),
          totalBytes: Value(total),
        ),
      );

  Future<int> deleteDownload(String id) =>
      (delete(downloads)..where((t) => t.id.equals(id))).go();
}
