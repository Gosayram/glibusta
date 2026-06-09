import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../search/data/composite_source.dart';
import '../../search/domain/book_source.dart';
import '../domain/book_details_repository.dart';

final bookDetailsRepositoryProvider = Provider<BookDetailsRepository>((ref) {
  final source = ref.watch(bookSourceProvider);
  return BookDetailsRepositoryImpl(source);
});

class BookDetailsRepositoryImpl implements BookDetailsRepository {
  final BookSource _source;

  BookDetailsRepositoryImpl(this._source);

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    return _source.getBookDetails(bookId);
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    return _source.getAvailableFormats(bookId);
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    return _source.getDownloadUrl(bookId, format);
  }
}
