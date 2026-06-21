import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/highlight_repository.dart';

// KeepAlive — single repository instance
final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HighlightRepository(db);
});

// Stream of all highlights for a book
final bookHighlightsProvider = StreamProvider.family<List<TextHighlight>, String>((ref, bookId) {
  return ref.watch(highlightRepositoryProvider).watchHighlightsForBook(bookId);
});
