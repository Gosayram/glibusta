import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/search/data/composite_source.dart';
import 'package:glibusta/features/search/domain/book_source.dart';
import 'package:glibusta/features/search/presentation/search_controller.dart';
import 'package:glibusta/shared/models/book.dart';
import 'package:glibusta/shared/models/download_task.dart';
import 'package:glibusta/shared/models/search_query.dart';

void main() {
  test('clearing results prevents a late search failure from overwriting state', () async {
    final source = _DelayedFailingBookSource();
    final container = ProviderContainer(
      overrides: [bookSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);

    final controller = container.read(searchControllerProvider.notifier);
    final pendingSearch = controller.search('stale query');
    controller.clearResults();
    source.completeWithError(StateError('network failed'));

    await pendingSearch;

    final state = container.read(searchControllerProvider);
    expect(state.lastQuery, isEmpty);
    expect(state.error, isNull);
    expect(state.isLoading, isFalse);
  });
}

class _DelayedFailingBookSource extends BookSource {
  final _books = Completer<SearchResultPage>();

  void completeWithError(Object error) => _books.completeError(error);

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) =>
      _books.future;

  @override
  Future<SearchAuthorsResultPage> searchAuthors(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) async => const SearchAuthorsResultPage(authors: []);

  @override
  Future<BookDetails> getBookDetails(String bookId) => Future.error(UnimplementedError());

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async => const [];

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) =>
      Future.error(UnimplementedError());
}
