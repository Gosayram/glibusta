import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../library/data/book_repository_impl.dart';
import '../../../shared/models/book.dart';

final userCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.collectionDao.getAllCollections();
});

final collectionProvider = FutureProvider.family<Collection?, String>((ref, collectionId) async {
  return ref.watch(databaseProvider).collectionDao.getCollectionById(collectionId);
});

final collectionBooksProvider = FutureProvider.family<List<Book>, String>((
  ref,
  collectionId,
) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.collectionDao.getBooksInCollection(collectionId);
  return ref.watch(bookRepositoryProvider).getBooksByIds(rows.map((book) => book.id).toList());
});
