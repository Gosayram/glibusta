import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/downloads/data/download_repository.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  test('creates downloads without an Android-specific absolute path', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DownloadRepositoryImpl(database, _FakeAppFileStorage());

    final task = await repository.startDownload(
      bookId: 'book-1',
      bookTitle: 'Book',
      format: BookFormat.epub,
      sourceUrl: 'https://example.com/book.epub',
    );

    expect(task.targetPath, '/app-support/glibusta/downloads/book-1.epub');
  });
}

class _FakeAppFileStorage implements AppFileStorage {
  @override
  Future<File> downloadFile(String bookId, BookFormat format) async =>
      File('/app-support/glibusta/downloads/$bookId.${format.name}');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
