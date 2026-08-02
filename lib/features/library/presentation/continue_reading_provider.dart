import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../data/book_repository_impl.dart';

part 'continue_reading_provider.g.dart';

class ContinueReadingBook {
  final Book book;
  final double progress;
  final DateTime lastReadAt;

  const ContinueReadingBook({
    required this.book,
    required this.progress,
    required this.lastReadAt,
  });
}

@riverpod
Future<List<ContinueReadingBook>> continueReading(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final repository = ref.watch(bookRepositoryProvider);

  final progressRows = await (db.select(db.readingProgress)
        ..where((t) => t.progressPercent.isBiggerThanValue(0))
        ..where((t) => t.progressPercent.isSmallerThanValue(1))
        ..orderBy([(t) => OrderingTerm.desc(t.lastRead)])
        ..limit(6))
      .get();

  if (progressRows.isEmpty) return [];

  final bookIds = progressRows.map((r) => r.bookId).toList();
  final books = await repository.getBooksByIds(bookIds);
  final bookMap = {for (final b in books) b.id: b};

  return progressRows
      .where((p) => bookMap.containsKey(p.bookId))
      .map(
        (p) => ContinueReadingBook(
          book: bookMap[p.bookId]!,
          progress: p.progressPercent,
          lastReadAt: p.lastRead,
        ),
      )
      .toList();
}
