import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../library/data/book_repository_impl.dart';
import '../../reader/data/book_open_service.dart';

part 'continue_reading_provider.g.dart';

class ContinueReadingInfo {
  final Book book;
  final String? currentChapterName;
  final int currentChapterIndex;
  final int totalChapters;
  final double progressPercent;
  final int estimatedMinutesLeft;
  final DateTime lastRead;

  const ContinueReadingInfo({
    required this.book,
    this.currentChapterName,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.progressPercent,
    required this.estimatedMinutesLeft,
    required this.lastRead,
  });

  String get progressText {
    if (totalChapters == 0) return '0%';
    return '${(progressPercent * 100).round()}%';
  }

  String get timeLeftText {
    if (estimatedMinutesLeft <= 0) return 'Почти готово';
    if (estimatedMinutesLeft < 60) return '~$estimatedMinutesLeft мин';
    final hours = estimatedMinutesLeft ~/ 60;
    final mins = estimatedMinutesLeft % 60;
    if (mins == 0) return '~$hours ч';
    return '~$hours ч $mins мин';
  }

  String get chapterText {
    if (currentChapterName != null) return currentChapterName!;
    if (totalChapters > 0) return 'Глава ${currentChapterIndex + 1} из $totalChapters';
    return 'Чтение';
  }
}

@riverpod
Future<List<ContinueReadingInfo>> continueReadingInfos(Ref ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final bookOpenService = ref.watch(bookOpenServiceProvider);

  final books = await repository.getBooksWithProgress();
  if (books.isEmpty) return [];

  // Batch load all reading progress in one query
  final allProgress = await db.bookDao.getAllReadingProgress();
  final progressMap = <String, ReadingProgressData>{};
  for (final progress in allProgress) {
    progressMap[progress.bookId] = progress;
  }

  final infos = <ContinueReadingInfo>[];

  for (final book in books) {
    final ReadingProgressData? progress = progressMap[book.id];
    if (progress == null) continue;

    final cachedBook = await bookOpenService.getCachedBook(book.id);
    final int totalChapters = cachedBook?.chapters.length ?? 0;
    final int currentChapter = progress.chapterIndex == 0
        ? progress.currentPosition
        : progress.chapterIndex;
    final DateTime lastRead = progress.lastRead;

    String? chapterName;
    if (cachedBook != null && currentChapter < cachedBook.chapters.length) {
      chapterName = cachedBook.chapters[currentChapter].title;
    }

    final int chaptersLeft = totalChapters - currentChapter;
    final int estimatedMinutesLeft = (chaptersLeft * 2).clamp(0, 9999);

    final double progressPercent = totalChapters > 0
        ? progress.progressPercent > 0
              ? progress.progressPercent
              : (currentChapter / totalChapters).clamp(0.0, 1.0)
        : 0.0;

    infos.add(
      ContinueReadingInfo(
        book: book,
        currentChapterName: chapterName,
        currentChapterIndex: currentChapter,
        totalChapters: totalChapters,
        progressPercent: progressPercent,
        estimatedMinutesLeft: estimatedMinutesLeft,
        lastRead: lastRead,
      ),
    );
  }

  infos.sort((a, b) => b.lastRead.compareTo(a.lastRead));
  return infos;
}
