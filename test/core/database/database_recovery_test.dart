import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/database/database_recovery.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recovery_test_');
    dbPath = p.join(tempDir.path, 'test.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<AppDatabase> createDb() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.customSelect('SELECT 1').get();
    return db;
  }

  group('DatabaseRecovery', () {
    test('createDatabaseBackup creates a file', () async {
      final db = await createDb();
      addTearDown(db.close);
      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final backupPath = await recovery.createDatabaseBackup();
      expect(File(backupPath).existsSync(), isTrue);
    });

    test('backup file is a valid SQLite database', () async {
      final db = await createDb();
      addTearDown(db.close);
      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final backupPath = await recovery.createDatabaseBackup();
      final isValid = await recovery.validateBackup(backupPath);
      expect(isValid, isTrue);
    });

    test('listBackups returns the backup', () async {
      final db = await createDb();
      addTearDown(db.close);
      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      await recovery.createDatabaseBackup();
      final backups = await recovery.listBackups();
      expect(backups, hasLength(1));
      expect(backups.first.path, endsWith('.recovery_backup'));
    });

    test('recoverFromBackup restores the database', () async {
      final db = await createDb();
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk1',
              bookId: 'b1',
              chapterIndex: 0,
              paragraphIndex: 0,
            ),
          );

      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final backupPath = await recovery.createDatabaseBackup();

      await db.delete(db.bookmarks).go();
      final afterDelete = await db.select(db.bookmarks).get();
      expect(afterDelete, isEmpty);

      await recovery.recoverFromBackup(backupPath);

      final restoredDb = await createDb();
      final afterRestore = await restoredDb.select(restoredDb.bookmarks).get();
      expect(afterRestore, hasLength(1));
      expect(afterRestore.first.id, 'bk1');
      await restoredDb.close();
    });

    test('reportLostData detects missing bookmarks', () async {
      final db = await createDb();
      addTearDown(db.close);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk1',
              bookId: 'b1',
              chapterIndex: 0,
              paragraphIndex: 0,
            ),
          );
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk2',
              bookId: 'b1',
              chapterIndex: 1,
              paragraphIndex: 0,
            ),
          );

      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final backupPath = await recovery.createDatabaseBackup();

      await (db.delete(db.bookmarks)..where((t) => t.id.equals('bk2'))).go();

      final report = await recovery.reportLostData(backupPath);
      expect(report.bookmarksLost, 1);
      expect(report.hasLoss, isTrue);
    });

    test('reportLostData shows no loss when data matches', () async {
      final db = await createDb();
      addTearDown(db.close);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: 'bk1',
              bookId: 'b1',
              chapterIndex: 0,
              paragraphIndex: 0,
            ),
          );

      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final backupPath = await recovery.createDatabaseBackup();

      final report = await recovery.reportLostData(backupPath);
      expect(report.hasLoss, isFalse);
      expect(report.bookmarksLost, 0);
      expect(report.highlightsLost, 0);
      expect(report.notesLost, 0);
      expect(report.quotesLost, 0);
      expect(report.readingProgressLost, 0);
    });

    test('validateBackup returns false for non-existent file', () async {
      final db = await createDb();
      addTearDown(db.close);
      final recovery = DatabaseRecovery(db: db, databasePath: dbPath);
      final isValid = await recovery.validateBackup('/nonexistent/path.db');
      expect(isValid, isFalse);
    });
  });
}
