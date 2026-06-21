import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'quote_repository.dart';

final quotesStreamProvider = StreamProvider.family<List<Quote>, String>((ref, bookId) {
  final database = ref.watch(databaseProvider);
  final repository = QuoteRepository(database);
  return repository.watchQuotes(bookId);
});
