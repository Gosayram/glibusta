import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/book_search_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_search_overlay.dart';

void main() {
  testWidgets('ignores a stale search response after a newer query starts', (tester) async {
    final service = _ControlledSearchService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _) {},
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.queries, ['first']);

    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.queries, ['first', 'second']);

    service.complete('first', const [_SearchResult('stale result')]);
    await tester.pump();
    expect(find.text('stale result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.complete('second', const [_SearchResult('fresh result')]);
    await tester.pump();
    expect(find.text('fresh result'), findsOneWidget);
  });
}

const _emptyBook = NormalizedBook(id: 'test', title: 'Test', authors: []);

class _ControlledSearchService extends BookSearchService {
  _ControlledSearchService() : super(_emptyBook);

  final queries = <String>[];
  final _pending = <String, Completer<List<BookSearchResult>>>{};

  @override
  Future<List<BookSearchResult>> search(
    String query, {
    int maxResults = 50,
    int? chapterIndex,
    bool matchCase = false,
  }) {
    queries.add(query);
    return (_pending[query] ??= Completer<List<BookSearchResult>>()).future;
  }

  @override
  void cancelPending() {}

  void complete(String query, List<BookSearchResult> results) {
    _pending[query]!.complete(results);
  }
}

class _SearchResult extends BookSearchResult {
  const _SearchResult(String text)
    : super(
        chapterIndex: 0,
        paragraphIndex: 0,
        chapterTitle: 'Chapter',
        matchText: text,
        beforeContext: '',
        afterContext: '',
      );
}
