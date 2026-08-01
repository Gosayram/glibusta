import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/failures.dart';
import '../../../core/http/http_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../shared/models/book.dart';
import '../../../shared/models/download_task.dart';
import '../../../shared/models/search_query.dart';
import '../domain/book_source.dart';
import 'flibusta_source.dart';

part 'composite_source.g.dart';

@riverpod
BookSource bookSource(Ref ref) {
  final sources = <BookSource>[
    ref.watch(flibustaSourceProvider),
  ];
  final logger = ref.watch(appLoggerProvider);
  return CompositeBookSource(sources, logger: logger);
}

class CompositeBookSource extends BookSource {
  CompositeBookSource(this.sources, {AppLogger? logger}) : _logger = logger;

  final List<BookSource> sources;
  final AppLogger? _logger;

  // Ponytail: simple in-memory cache, max 50 entries, 5 min TTL
  final Map<String, _CacheEntry<SearchResultPage>> _searchCache = {};
  final Map<String, _CacheEntry<SearchAuthorsResultPage>> _authorCache = {};
  static const _cacheTtl = Duration(minutes: 5);
  static const _cacheMaxSize = 50;

  String _searchKey(SearchQuery q) =>
      '${q.query}|${q.page}|${q.author}|${q.title}|${q.series}|${q.genre}|${q.filters.format}|${q.filters.language}|${q.filters.dateFrom}|${q.filters.dateTo}';

  @override
  Future<SearchResultPage> searchBooks(SearchQuery query, {CancelToken? cancelToken}) async {
    final key = _searchKey(query);
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) return cached.value;
    _searchCache.remove(key);

    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final result = await source.searchBooks(query, cancelToken: cancelToken);
        if (result.books.isNotEmpty) {
          _put(_searchCache, key, result);
          return result;
        }
      } on AppFailure catch (e) {
        _logger?.severe(
          'SearchBooks failed (${source.runtimeType}): ${e.message}',
          name: 'CompositeSource',
          error: e,
        );
        errors.add(e);
      } on Object catch (e, st) {
        if (isCancellation(e)) rethrow;
        _logger?.severe(
          'SearchBooks unexpected error (${source.runtimeType}): $e',
          name: 'CompositeSource',
          error: e,
          st: st,
        );
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    if (errors.isNotEmpty) {
      throw SourceUnavailableFailure(
        'All sources failed: ${errors.map((e) => e.message).join('; ')}',
      );
    }
    return SearchResultPage(
      books: const [],
      totalCount: 0,
      currentPage: query.page,
      totalPages: 0,
      hasNextPage: false,
    );
  }

  @override
  Future<SearchAuthorsResultPage> searchAuthors(
    SearchQuery query, {
    CancelToken? cancelToken,
  }) async {
    final key = _searchKey(query);
    final cached = _authorCache[key];
    if (cached != null && !cached.isExpired) return cached.value;
    _authorCache.remove(key);

    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final result = await source.searchAuthors(query, cancelToken: cancelToken);
        if (result.authors.isNotEmpty) {
          _put(_authorCache, key, result);
          return result;
        }
      } on AppFailure catch (e) {
        _logger?.warning(
          'SearchAuthors failed (${source.runtimeType}): ${e.message}',
          name: 'CompositeSource',
          error: e,
        );
        errors.add(e);
      } on Object catch (e, st) {
        if (isCancellation(e)) rethrow;
        _logger?.warning(
          'SearchAuthors unexpected error (${source.runtimeType}): $e',
          name: 'CompositeSource',
          error: e,
          st: st,
        );
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    return const SearchAuthorsResultPage(authors: []);
  }

  @override
  Future<BookDetails> getBookDetails(String bookId) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        return await source.getBookDetails(bookId);
      } on AppFailure catch (e) {
        _logger?.severe(
          'GetBookDetails failed ($bookId, ${source.runtimeType}): ${e.message}',
          name: 'CompositeSource',
          error: e,
        );
        errors.add(e);
      } on Object catch (e, st) {
        if (isCancellation(e)) rethrow;
        _logger?.severe(
          'GetBookDetails unexpected error ($bookId): $e',
          name: 'CompositeSource',
          error: e,
          st: st,
        );
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    throw SourceUnavailableFailure(
      'All sources failed for book $bookId: ${errors.map((e) => e.message).join('; ')}',
    );
  }

  @override
  Future<List<BookFormat>> getAvailableFormats(String bookId) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final formats = await source.getAvailableFormats(bookId);
        if (formats.isNotEmpty) return formats;
      } on AppFailure catch (e) {
        _logger?.warning(
          'GetAvailableFormats failed ($bookId, ${source.runtimeType}): ${e.message}',
          name: 'CompositeSource',
          error: e,
        );
        errors.add(e);
      } on Object catch (e, st) {
        if (isCancellation(e)) rethrow;
        _logger?.warning(
          'GetAvailableFormats unexpected error ($bookId): $e',
          name: 'CompositeSource',
          error: e,
          st: st,
        );
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    return const [];
  }

  @override
  Future<String> getDownloadUrl(String bookId, BookFormat format) async {
    final errors = <AppFailure>[];
    for (final source in sources) {
      try {
        final url = await source.getDownloadUrl(bookId, format);
        if (url.isNotEmpty) return url;
      } on AppFailure catch (e) {
        _logger?.severe(
          'GetDownloadUrl failed ($bookId, ${format.name}, ${source.runtimeType}): ${e.message}',
          name: 'CompositeSource',
          error: e,
        );
        errors.add(e);
      } on Object catch (e, st) {
        if (isCancellation(e)) rethrow;
        _logger?.severe(
          'GetDownloadUrl unexpected error ($bookId, ${format.name}): $e',
          name: 'CompositeSource',
          error: e,
          st: st,
        );
        errors.add(ParserFailure('Unexpected error: $e'));
      }
    }
    throw SourceUnavailableFailure(
      'No download URL found for book $bookId format ${format.name}',
    );
  }

  void _put<T>(Map<String, _CacheEntry<T>> cache, String key, T value) {
    if (cache.length >= _cacheMaxSize) {
      final oldest = cache.keys.first;
      cache.remove(oldest);
    }
    cache[key] = _CacheEntry(value);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime _createdAt;
  _CacheEntry(this.value) : _createdAt = DateTime.now();
  bool get isExpired => DateTime.now().difference(_createdAt) > CompositeBookSource._cacheTtl;
}
