import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/book.dart';
import '../../library/data/book_repository_impl.dart';

final recentBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getAllBooks();
});
