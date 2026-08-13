import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/book.dart';
import '../../library/data/book_repository_impl.dart';

part 'smart_collections_provider.g.dart';

enum SmartCollectionType {
  reading('Сейчас читаю', Icons.auto_stories),
  abandoned('Брошенные', Icons.bookmark_remove),
  toRead('Дочитать', Icons.bookmark_add),
  recentlyOpened('Недавно открытые', Icons.history),
  noCover('Без обложки', Icons.image_not_supported),
  noAuthor('Без автора', Icons.person_off),
  newBooks('Новые', Icons.fiber_new);

  const SmartCollectionType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SmartCollection {
  final SmartCollectionType type;
  final List<Book> books;

  const SmartCollection({required this.type, required this.books});

  bool get isEmpty => books.isEmpty;
}

@riverpod
Future<List<SmartCollection>> smartCollections(Ref ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  final db = ref.watch(databaseProvider);

  final allBooks = await repository.getAllBooks();
  if (allBooks.isEmpty) return [];

  final now = DateTime.now();
  final collections = <SmartCollection>[];

  // ponytail: getAllReadingProgress is best-effort — if it fails, collections
  // degrade gracefully (reading/abandoned empty, toRead = allBooks).
  final progressMap = <String, ReadingProgressData>{};
  try {
    final allProgress = await db.bookDao.getAllReadingProgress();
    for (final progress in allProgress) {
      progressMap[progress.bookId] = progress;
    }
  } on Object catch (_) {
    // Progress unavailable — collections will show partial results
  }

  // Currently reading: has progress, opened within last 30 days
  final reading = allBooks.where((b) {
    final progress = progressMap[b.id];
    if (progress == null) return false;
    return now.difference(progress.lastRead).inDays <= 30;
  }).toList();
  collections.add(SmartCollection(type: SmartCollectionType.reading, books: reading));

  // Abandoned: has progress, last read > 30 days ago
  final abandoned = allBooks.where((b) {
    final progress = progressMap[b.id];
    if (progress == null) return false;
    return now.difference(progress.lastRead).inDays > 30;
  }).toList();
  collections.add(SmartCollection(type: SmartCollectionType.abandoned, books: abandoned));

  // To read: no progress
  final toRead = allBooks.where((b) => !progressMap.containsKey(b.id)).toList();
  collections.add(SmartCollection(type: SmartCollectionType.toRead, books: toRead));

  // Recently opened: last read < 7 days
  final recentlyOpened = reading.where((b) {
    final progress = progressMap[b.id]!;
    return now.difference(progress.lastRead).inDays < 7;
  }).toList();
  collections.add(SmartCollection(type: SmartCollectionType.recentlyOpened, books: recentlyOpened));

  // No cover
  final noCover = allBooks
      .where(
        (b) =>
            (b.coverUrl == null || b.coverUrl!.isEmpty) &&
            (b.coverPath == null || b.coverPath!.isEmpty),
      )
      .toList();
  collections.add(SmartCollection(type: SmartCollectionType.noCover, books: noCover));

  // No author
  final noAuthor = allBooks.where((b) => b.authorIds.isEmpty).toList();
  collections.add(SmartCollection(type: SmartCollectionType.noAuthor, books: noAuthor));

  // New books: added to library in last 7 days
  final newBooks = allBooks.where((b) {
    if (b.dateAdded == null) return false;
    return now.difference(b.dateAdded!).inDays < 7;
  }).toList();
  collections.add(SmartCollection(type: SmartCollectionType.newBooks, books: newBooks));

  return collections;
}
