import 'package:flutter_test/flutter_test.dart';

import 'package:glibusta/features/search/domain/book_source.dart';
import 'package:glibusta/shared/models/search_query.dart';
import 'package:glibusta/shared/models/book.dart';

void main() {
  test('BookSource mock returns empty results', () async {
    final source = MockBookSource();
    final result = await source.searchBooks(SearchQuery(query: 'test'));
    
    expect(result.books, isEmpty);
    expect(result.hasNextPage, isFalse);
  });

  test('BookSource mock returns details', () async {
    final source = MockBookSource();
    final details = await source.getBookDetails('123');
    
    expect(details.book.id, '123');
    expect(details.availableFormats, contains(BookFormat.fb2));
  });
}