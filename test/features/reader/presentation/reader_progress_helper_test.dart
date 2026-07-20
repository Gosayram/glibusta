import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_progress_helper.dart';

void main() {
  test('restores an Arabic/Hebrew EPUB semantic position after reopening', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    const bookId = 'rtl-epub';
    final savedPosition = ReaderPosition(
      bookId: bookId,
      // These positions point into Arabic and Hebrew EPUB chapters. Progress
      // is semantic, so it must not depend on visual RTL layout or direction.
      chapterIndex: 1,
      paragraphIndex: 3,
      localOffset: 42.5,
      progressPercent: 0.625,
      chapterId: 'chapter-עברית-٢',
      textOffset: 87,
      updatedAt: DateTime.utc(2026, 7, 20),
    );
    final saver = ReaderProgressHelper(database, bookId, AppLogger());
    final rowFuture =
        (database.select(
          database.readingProgress,
        )..where((table) => table.bookId.equals(bookId))).watchSingleOrNull().firstWhere(
          (row) => row != null,
        );

    saver.saveProgress(savedPosition, 8);
    await rowFuture;

    final reopened = await ReaderProgressHelper(
      database,
      bookId,
      AppLogger(),
    ).loadSavedPosition(2);

    expect(reopened.chapterIndex, savedPosition.chapterIndex);
    expect(reopened.paragraphIndex, savedPosition.paragraphIndex);
    expect(reopened.localOffset, savedPosition.localOffset);
    expect(reopened.progressPercent, savedPosition.progressPercent);
    expect(reopened.chapterId, savedPosition.chapterId);
    expect(reopened.textOffset, savedPosition.textOffset);
  });
}
