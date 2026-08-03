import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/book_search_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_search_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
}

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
    expect(_richTextContaining('stale result'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.complete('second', const [_SearchResult('fresh result')]);
    await tester.pump();
    expect(_richTextContaining('fresh result'), findsOneWidget);
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
    expect(_richTextContaining('Matching paragraph'), findsOneWidget);
    expect(find.text(afterExcerpt), findsOneWidget);
    expect(
      tester.getSemantics(_richTextContaining('Matching paragraph')),
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

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'recent query'),
        matching: find.byIcon(Icons.close),
      ),
    );
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

  testWidgets('prev/next buttons hidden when no results', (tester) async {
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

    expect(find.byTooltip('Предыдущее совпадение'), findsNothing);
    expect(find.byTooltip('Следующее совпадение'), findsNothing);
  });

  testWidgets('prev/next buttons appear with match counter after search', (tester) async {
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

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'hello',
      const [
        _SearchResult('match one'),
        _SearchResult('match two'),
        _SearchResult('match three'),
      ],
    );
    await tester.pump();

    expect(find.byTooltip('Предыдущее совпадение'), findsOneWidget);
    expect(find.byTooltip('Следующее совпадение'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('next button advances match index and calls onJumpToResult', (tester) async {
    final service = _ControlledSearchService();
    final jumped = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, matchIndex) => jumped.add(matchIndex),
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'word');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'word',
      const [
        _SearchResult('first', paragraphIndex: 10),
        _SearchResult('second', chapterIndex: 1, paragraphIndex: 5),
        _SearchResult('third', chapterIndex: 2),
      ],
    );
    await tester.pump();

    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byTooltip('Следующее совпадение'));
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);
    expect(jumped, [1]);

    await tester.tap(find.byTooltip('Следующее совпадение'));
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
    expect(jumped, [1, 2]);
  });

  testWidgets('prev button decrements match index', (tester) async {
    final service = _ControlledSearchService();
    final jumped = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, matchIndex) => jumped.add(matchIndex),
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'word');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'word',
      const [
        _SearchResult('first'),
        _SearchResult('second'),
        _SearchResult('third'),
      ],
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Предыдущее совпадение'));
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
    expect(jumped, [2]);
  });

  testWidgets('highlighted query text is bold in search results', (tester) async {
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

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'cat',
      const [_SearchResult('The cat sat on the mat')],
    );
    await tester.pump();

    final richText = tester.widget<RichText>(_richTextContaining('The cat sat on the mat'));
    final spans = (richText.text as TextSpan).children!;
    final boldSpans = spans
        .whereType<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.w700)
        .toList();
    expect(boldSpans, hasLength(1));
    expect(boldSpans.first.text, 'cat');
  });

  testWidgets('next wraps around from last to first', (tester) async {
    final service = _ControlledSearchService();
    final jumped = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookSearchOverlay(
            searchService: service,
            onJumpToResult: (_, _, _, matchIndex) => jumped.add(matchIndex),
            onDismiss: () {},
            theme: ReaderTheme.light,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump(const Duration(milliseconds: 300));
    service.complete(
      'x',
      const [_SearchResult('a'), _SearchResult('b')],
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Следующее совпадение'));
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Следующее совпадение'));
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(jumped, [1, 0]);
  });
}

const _emptyBook = NormalizedBook(id: 'test', title: 'Test', authors: []);

class _ControlledSearchService extends BookSearchService {
  _ControlledSearchService() : super(_emptyBook, '/dummy');

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
    super.chapterIndex = 0,
    super.paragraphIndex = 0,
  }) : super(
         chapterTitle: 'Chapter',
         matchText: text,
       );
}
