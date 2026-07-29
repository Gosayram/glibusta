import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/reader_side_panel.dart';

void main() {
  testWidgets('exposes a collapsible side-panel TOC group as an accessible control', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final scrollController = ScrollController();
    final semantics = tester.ensureSemantics();
    addTearDown(database.close);
    addTearDown(scrollController.dispose);
    const title = '1 Раздел';
    const childTitle = '1.1 Подраздел';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSidePanel(
              metadata: const NormalizedBookMetadata(
                id: 'book-1',
                title: 'Book',
                authors: [],
                chapterCount: 4,
                chapterTitles: [title, childTitle, '1.2 Ещё подраздел', '2 Второй раздел'],
              ),
              currentChapterIndex: 0,
              scrollController: scrollController,
              width: 360,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('side-panel-toc-group-toggle-0'));
    expect(toggle, findsOneWidget);
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Свернуть раздел $title',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Свернуть раздел $title'));
    await tester.pump();

    expect(find.text(childTitle), findsNothing);
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Развернуть раздел $title',
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
      ),
    );

    semantics.dispose();
  });
}
