import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
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

  test('keeps distinct recent searches when one query is repeated', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final source = _SuccessfulBookSource();
    final container = ProviderContainer(
      overrides: [
        bookSourceProvider.overrideWithValue(source),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(database.close);
    addTearDown(container.dispose);

    final controller = container.read(searchControllerProvider.notifier);
    await controller.search('other');
    for (var i = 0; i < 8; i++) {
      await controller.search('repeated');
    }

    final rows = await database.select(database.searchHistory).get();
    expect(rows, hasLength(2));
    await controller.loadHistory();

    expect(container.read(searchControllerProvider).history, ['repeated', 'other']);
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

class _SuccessfulBookSource extends BookSource {
  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    return SearchResultPage(
      books: [
        const Book(
          id: 'book',
          title: 'Book',
          authorIds: [],
          genreIds: [],
          description: null,
          coverUrl: null,
          publishDate: null,
          availableFormats: [],
          source: BookSourceInfo(sourceId: 'test', sourceUrl: 'https://example.com'),
        ),
      ],
      totalCount: 1,
      currentPage: query.page,
      totalPages: 1,
      hasNextPage: false,
    );
  }

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
