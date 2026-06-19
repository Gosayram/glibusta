import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../data/composite_source.dart';
import '../domain/book_source.dart';

part 'search_controller.g.dart';
part 'search_controller.freezed.dart';

@riverpod
class SearchControllerNotifier extends _$SearchControllerNotifier {
  CancelToken? _currentToken;
  CancelToken? _authorToken;
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  SearchState build() {
    ref.onDispose(() {
      _currentToken?.cancel();
      _currentToken = null;
      _authorToken?.cancel();
      _authorToken = null;
    });
    return const SearchState();
  }

  BookSource get _source => ref.read(bookSourceProvider);

  Future<void> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      clearResults();
      return;
    }

    _logger.info('Searching: "$normalized"', name: 'Search');

    _currentToken?.cancel();
    _authorToken?.cancel();
    _currentToken = CancelToken();
    _authorToken = CancelToken();
    final localAuthorToken = _authorToken;
    state = state.copyWith(
      isLoading: true,
      lastQuery: normalized,
      error: null,
    );

    final searchQuery = SearchQuery(
      query: normalized,
      filters: state.filters,
    );

    try {
      SearchResultPage bookResult;
      SearchAuthorsResultPage authorResult;

      final bookToken = CancelToken();
      _currentToken = bookToken;

      Object? bookError;

      try {
        bookResult = await _source.searchBooks(searchQuery, cancelToken: bookToken);
      } on Object catch (e) {
        bookError = e;
        _logger.warning('Book search failed: $e', name: 'Search', error: e);
        bookResult = SearchResultPage(
          books: const [],
          totalCount: 0,
          currentPage: searchQuery.page,
          totalPages: 0,
          hasNextPage: false,
        );
      }

      if (!ref.mounted) return;

      try {
        authorResult = await _source.searchAuthors(searchQuery, cancelToken: localAuthorToken);
      } on Object catch (e) {
        _logger.warning('Author search failed: $e', name: 'Search', error: e);
        authorResult = const SearchAuthorsResultPage(authors: []);
      }

      if (!ref.mounted) return;

      if (bookResult.books.isEmpty && authorResult.authors.isEmpty && bookError != null) {
        state = state.copyWith(
          isLoading: false,
          error: bookError.toString(),
          books: const [],
          authors: const [],
        );
        return;
      }

      if (!ref.mounted) return;
      _logger.info(
        'Search returned ${bookResult.books.length} books, ${authorResult.authors.length} authors',
        name: 'Search',
      );
      unawaited(_rememberSearch(normalized));
      state = state.copyWith(
        books: bookResult.books,
        authors: authorResult.authors,
        isLoading: false,
        hasMore: bookResult.hasNextPage,
        currentPage: bookResult.currentPage,
        error: null,
      );
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      _logger.severe('Search failed: $e', name: 'Search', error: e, st: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.lastQuery.isEmpty) return;

    final nextPage = state.currentPage + 1;
    _logger.info('Loading more: page $nextPage', name: 'Search');

    state = state.copyWith(isLoading: true);

    final searchQuery = SearchQuery(
      query: state.lastQuery,
      page: nextPage,
      filters: state.filters,
    );
    _currentToken?.cancel();
    _currentToken = CancelToken();

    try {
      final result = await _source.searchBooks(searchQuery, cancelToken: _currentToken);
      if (!ref.mounted) return;
      _logger.info('Load more returned ${result.books.length} results', name: 'Search');
      state = state.copyWith(
        books: [...state.books, ...result.books],
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
        error: null,
      );
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      _logger.severe('Load more failed: $e', name: 'Search', error: e, st: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilters(SearchFilters filters) {
    final query = state.lastQuery;
    state = state.copyWith(
      filters: filters,
      books: const [],
      authors: const [],
      isLoading: false,
      hasMore: false,
      currentPage: 0,
      error: null,
    );

    if (query.isNotEmpty) {
      unawaited(search(query));
    }
  }

  Future<void> loadHistory() async {
    final db = ref.read(databaseProvider);
    final rows =
        await (db.select(db.searchHistory)
              ..orderBy([(table) => OrderingTerm.desc(table.searchedAt)])
              ..limit(8))
            .get();
    if (!ref.mounted) return;
    state = state.copyWith(
      history: rows
          .map((row) => row.query.trim())
          .where((query) => query.isNotEmpty)
          .toSet()
          .toList(),
    );
  }

  Future<void> _rememberSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final db = ref.read(databaseProvider);
    await db
        .into(db.searchHistory)
        .insert(
          SearchHistoryCompanion.insert(
            query: normalized,
            type: 'online',
          ),
        );

    if (!ref.mounted) return;
    unawaited(loadHistory());
  }

  Future<void> clearHistory() async {
    final db = ref.read(databaseProvider);
    await db.delete(db.searchHistory).go();
    if (!ref.mounted) return;
    state = state.copyWith(history: const []);
  }

  void clearResults() {
    _currentToken?.cancel();
    _currentToken = null;
    _authorToken?.cancel();
    _authorToken = null;
    state = state.copyWith(
      books: const [],
      authors: const [],
      isLoading: false,
      error: null,
      hasMore: false,
      lastQuery: '',
    );
  }
}

@freezed
abstract class SearchState with _$SearchState {
  const factory SearchState({
    @Default([]) List<Book> books,
    @Default([]) List<SearchAuthorResult> authors,
    @Default(false) bool isLoading,
    String? error,
    @Default(false) bool hasMore,
    @Default(0) int currentPage,
    @Default('') String lastQuery,
    @Default([]) List<String> history,
    @Default(SearchFilters()) SearchFilters filters,
  }) = _SearchState;

  const SearchState._();
}
