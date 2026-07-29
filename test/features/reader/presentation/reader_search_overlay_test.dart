import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/book_search_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_search_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ignores a stale search response after a newer query starts', (tester) async {
    final service = _ControlledSearchService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, _) {},
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

  testWidgets('clearing a query cancels its pending debounce', (tester) async {
    final service = _ControlledSearchService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, _) {},
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'obsolete');
    await tester.pump();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.queries, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ничего не найдено'), findsNothing);
  });

  testWidgets('shows bounded neighbouring context in an accessible search result', (tester) async {
    final service = _ControlledSearchService();
    final semantics = tester.ensureSemantics();
    final before = 'a' * 120;
    final after = 'b' * 120;
    ReaderPosition? jumpedPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (position, _, _, _) => jumpedPosition = position,
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'match');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'match',
      [
        _SearchResult(
          'Matching paragraph',
          beforeContext: before,
          afterContext: after,
        ),
      ],
    );
    await tester.pump();

    final beforeExcerpt = '…${before.substring(before.length - 96)}';
    final afterExcerpt = '${after.substring(0, 96)}…';
    final semanticsLabel =
        'Результат поиска. Chapter. Matching paragraph Перед: $beforeExcerpt. После: '
        '$afterExcerpt.';
    expect(find.text(beforeExcerpt), findsOneWidget);
    expect(find.text('Matching paragraph'), findsOneWidget);
    expect(find.text(afterExcerpt), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Matching paragraph')),
      matchesSemantics(
        label: semanticsLabel,
        isButton: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel(semanticsLabel));
    expect(jumpedPosition?.chapterIndex, 0);
    expect(jumpedPosition?.paragraphIndex, 0);

    semantics.dispose();
  });

  testWidgets('shows, deletes and clears local explicit history', (tester) async {
    SharedPreferences.setMockInitialValues({
      'reader_search_history/test': <String>['recent query', 'older query'],
    });
    final service = _ControlledSearchService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, _) {},
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Недавние запросы'), findsOneWidget);
    expect(find.text('recent query'), findsOneWidget);
    expect(find.text('older query'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить запрос').first);
    await tester.pump();
    expect(find.text('recent query'), findsNothing);
    expect(find.text('older query'), findsOneWidget);

    await tester.tap(find.text('Очистить'));
    await tester.pump();
    expect(find.text('Недавние запросы'), findsNothing);
  });

  testWidgets('reuses a recent query without saving while typing', (tester) async {
    SharedPreferences.setMockInitialValues({
      'reader_search_history/test': <String>['recent query'],
    });
    final service = _ControlledSearchService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, _) {},
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('recent query'));
    await tester.pump();

    expect(service.queries, ['recent query']);
    expect((tester.widget<TextField>(find.byType(TextField))).controller!.text, 'recent query');
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
    bool useRegex = false,
    bool wholeWord = false,
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
  const _SearchResult(
    String text, {
    super.beforeContext = '',
    super.afterContext = '',
  }) : super(
         chapterIndex: 0,
         paragraphIndex: 0,
         chapterTitle: 'Chapter',
         matchText: text,
       );
}
