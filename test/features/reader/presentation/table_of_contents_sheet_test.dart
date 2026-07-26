import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/presentation/table_of_contents_sheet.dart';

void main() {
  testWidgets('positions the current chapter in view without jumping to it', (tester) async {
    const currentChapter = 24;
    var jumpCount = 0;
    final chapterTitles = List<String>.generate(
      40,
      (index) => 'Chapter ${index + 1}',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => TableOfContentsSheet.show(
                context,
                metadata: NormalizedBookMetadata(
                  id: 'book-1',
                  title: 'Book',
                  authors: const [],
                  chapterCount: chapterTitles.length,
                  chapterTitles: chapterTitles,
                ),
                currentChapterIndex: currentChapter,
                onJumpToPosition: (_) => jumpCount++,
              ),
              child: const Text('Open contents'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open contents'));
    await tester.pumpAndSettle();

    final currentTitle = 'Chapter ${currentChapter + 1}';
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(900));
    expect(find.text(currentTitle), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(currentTitle)).dy,
      greaterThan(0),
    );
    expect(jumpCount, 0);
  });
}
