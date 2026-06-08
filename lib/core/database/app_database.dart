import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [SavedBooks, Authors, Genres, Downloads, ReadingProgress])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
  );

  // --- SavedBooks ---
  Future<List<SavedBook>> getAllBooks() async {
    return select(savedBooks).get();
  }

  Future<SavedBook?> getBookById(String id) async {
    return (select(savedBooks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertBook(SavedBooksCompanion entry) {
    return into(savedBooks).insertOnConflictUpdate(entry);
  }

  Future<int> deleteBook(String id) {
    return (delete(savedBooks)..where((t) => t.id.equals(id))).go();
  }

  // --- Authors ---
  Future<List<Author>> getAllAuthors() async {
    return select(authors).get();
  }

  Future<int> insertAuthor(AuthorsCompanion entry) {
    return into(authors).insertOnConflictUpdate(entry);
  }

  // --- Genres ---
  Future<List<Genre>> getAllGenres() async {
    return select(genres).get();
  }

  Future<int> insertGenre(GenresCompanion entry) {
    return into(genres).insertOnConflictUpdate(entry);
  }

  // --- Downloads ---
  Future<List<Download>> getAllDownloads() async {
    return (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Stream<List<Download>> watchAllDownloads() {
    return (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<Download?> getDownloadById(String id) async {
    return (select(downloads)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertDownload(DownloadsCompanion entry) {
    return into(downloads).insertOnConflictUpdate(entry);
  }

  Future<int> updateDownloadStatus(String id, DownloadStatusDb status) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(status: Value(status)),
    );
  }

  Future<int> updateDownloadProgress(String id, int downloaded, int total) {
    return (update(downloads)..where((t) => t.id.equals(id))).write(
      DownloadsCompanion(
        downloadedBytes: Value(downloaded),
        totalBytes: Value(total),
      ),
    );
  }

  Future<int> deleteDownload(String id) {
    return (delete(downloads)..where((t) => t.id.equals(id))).go();
  }

  // --- Reading Progress ---
  Future<ReadingProgressData?> getReadingProgress(String bookId) async {
    return (select(readingProgress)..where((t) => t.bookId.equals(bookId))).getSingleOrNull();
  }

  Future<int> upsertReadingProgress(ReadingProgressCompanion entry) {
    return into(readingProgress).insertOnConflictUpdate(entry);
  }

  Future<int> deleteReadingProgress(String bookId) {
    return (delete(readingProgress)..where((t) => t.bookId.equals(bookId))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'glibusta', 'glibusta.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
