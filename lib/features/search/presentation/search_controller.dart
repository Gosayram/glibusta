import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/book.dart';
import '../../../shared/models/search_query.dart';
import '../data/composite_source.dart';
import '../domain/book_source.dart';

final searchControllerProvider =
    StateNotifierProvider<SearchStateController, SearchState>((ref) {
  final source = ref.watch(compositeSourceProvider);
  return SearchStateController(source);
});

class SearchState {
  final List<Book> books;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final String lastQuery;

  const SearchState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = false,
    this.currentPage = 0,
    this.lastQuery = '',
  });

  SearchState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    String? lastQuery,
  }) {
    return SearchState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      lastQuery: lastQuery ?? this.lastQuery,
    );
  }
}

class SearchStateController extends StateNotifier<SearchState> {
  final BookSource source;
  CancelableOperation<SearchResultPage>? _currentSearch;

  SearchStateController(this.source) : super(const SearchState());

  Future<void> search(String query) async {
    _currentSearch?.cancel();
    state = state.copyWith(
      isLoading: true,
      error: null,
      lastQuery: query,
    );

    final searchQuery = SearchQuery(query: query);
    _currentSearch =
        CancelableOperation.fromFuture(source.searchBooks(searchQuery));

    try {
      final result = await _currentSearch!.value;
      if (!mounted) return;
      state = state.copyWith(
        books: result.books,
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.lastQuery.isEmpty) return;

    state = state.copyWith(isLoading: true);

    final searchQuery = SearchQuery(
      query: state.lastQuery,
      page: state.currentPage + 1,
    );
    _currentSearch =
        CancelableOperation.fromFuture(source.searchBooks(searchQuery));

    try {
      final result = await _currentSearch!.value;
      if (!mounted) return;
      state = state.copyWith(
        books: [...state.books, ...result.books],
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearResults() {
    _currentSearch?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _currentSearch?.cancel();
    super.dispose();
  }
}
