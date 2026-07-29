import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  group('Reader page direction', () {
    testWidgets('uses EPUB RTL metadata for paginated page navigation', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(_reader(scrollController: scrollController));

      _expectRtlPageView(tester);
    });

    testWidgets('uses EPUB RTL metadata for fixed-layout page navigation', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(_reader(scrollController: scrollController, fixedLayout: true));

      _expectRtlPageView(tester);
    });
  });
}

Widget _reader({required ScrollController scrollController, bool fixedLayout = false}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 640,
        child: ReaderContentBody(
          metadata: NormalizedBookMetadata(
            id: fixedLayout ? 'rtl-fixed' : 'rtl-paginated',
            title: 'كتاب',
            authors: const [],
            chapterCount: 1,
            chapterTitles: const ['الفصل الأول'],
            metadata: {
              'textDirection': 'rtl',
              if (fixedLayout) 'isFixedLayout': true,
            },
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'الفصل الأول',
              blocks: [ReaderBlock(index: 0, text: 'هذا نص عربي قابل للقراءة.')],
            ),
          },
          settings: const ReaderSettings(),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    ),
  );
}

void _expectRtlPageView(WidgetTester tester) {
  final pageView = find.byType(PageView);
  expect(pageView, findsOneWidget);

  final directions = find
      .ancestor(of: pageView, matching: find.byType(Directionality))
      .evaluate()
      .map((element) => (element.widget as Directionality).textDirection);
  expect(directions, contains(TextDirection.rtl));
}

void _ignoreTap(TapUpDetails _) {}
