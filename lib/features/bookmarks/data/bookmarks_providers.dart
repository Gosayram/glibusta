import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'bookmark_repository.dart';

final bookmarksStreamProvider = StreamProvider.family<List<Bookmark>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = BookmarkRepository(database);
  return repository.watchBookmarks(bookId);
});
