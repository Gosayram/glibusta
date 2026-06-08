import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:async/async.dart';

import '../../../shared/models/search_query.dart';
import '../../../shared/models/book.dart';
import '../domain/book_source.dart';
import '../data/flibusta_source.dart';

final searchControllerProvider =
    StateNotifierProvider<SearchStateController, SearchState>((ref) {
  final source = ref.watch(flibustaSourceProvider);
  return SearchStateController(source);
});

class SearchState {
  final List<Book> books;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const SearchState({
    this.books = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = false,
    this.currentPage = 0,
  });

  SearchState copyWith({
    List<Book>? books,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return SearchState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class SearchStateController extends StateNotifier<SearchState> {
  final BookSource source;
  CancelableOperation<SearchResultPage>? _currentSearch;

  SearchStateController(this.source) : super(const SearchState());

  Future<void> search(String query) async {
    _currentSearch?.cancel();
    state = state.copyWith(isLoading: true, error: null);

    final searchQuery = SearchQuery(query: query, page: 0);
    _currentSearch = CancelableOperation.fromFuture(source.searchBooks(searchQuery));

    try {
      final result = await _currentSearch!.value;
      state = state.copyWith(
        books: result.books,
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    final searchQuery = SearchQuery(query: '', page: state.currentPage + 1);
    _currentSearch = CancelableOperation.fromFuture(source.searchBooks(searchQuery));

    try {
      final result = await _currentSearch!.value;
      state = state.copyWith(
        books: [...state.books, ...result.books],
        isLoading: false,
        hasMore: result.hasNextPage,
        currentPage: result.currentPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _currentSearch?.cancel();
    super.dispose();
  }
}