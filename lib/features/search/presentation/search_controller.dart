import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../data/composite_source.dart';
import '../domain/book_source.dart';

part 'search_controller.g.dart';

@riverpod
class SearchControllerNotifier extends _$SearchControllerNotifier {
  CancelToken? _currentToken;
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  SearchState build() {
    ref.onDispose(() {
      _currentToken?.cancel();
      _currentToken = null;
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
    _currentToken = CancelToken();
    state = state.copyWith(
      isLoading: true,
      lastQuery: normalized,
      clearError: true,
    );

    final searchQuery = SearchQuery(
      query: normalized,
      filters: state.filters,
    );

    try {
      final result = await _source.searchBooks(searchQuery, cancelToken: _currentToken);
      if (!ref.mounted) return;
      _logger.info('Search returned ${result.books.length} results', name: 'Search');
      unawaited(_rememberSearch(normalized));
      state = state.copyWith(
        books: result.books,
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
        clearError: true,
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
        clearError: true,
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
      isLoading: false,
      hasMore: false,
      currentPage: 0,
      clearError: true,
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
    state = state.copyWith(
      books: const [],
      isLoading: false,
      clearError: true,
      hasMore: false,
      lastQuery: '',
    );
  }
}

class SearchState {
  final List<Book> books;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final String lastQuery;
  final List<String> history;
  final SearchFilters filters;

  const SearchState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = false,
    this.currentPage = 0,
    this.lastQuery = '',
    this.history = const [],
    this.filters = const SearchFilters(),
  });

  SearchState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    String? lastQuery,
    List<String>? history,
    SearchFilters? filters,
    bool clearError = false,
  }) {
    return SearchState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      lastQuery: lastQuery ?? this.lastQuery,
      history: history ?? this.history,
      filters: filters ?? this.filters,
    );
  }
}
