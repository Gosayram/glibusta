import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.light(),
  home: Scaffold(
    body: SizedBox(width: 400, height: 800, child: child),
  ),
);

NormalizedBookMetadata _meta({int chapterCount = 1}) => NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: const [],
  chapterCount: chapterCount,
  chapterTitles: List.generate(chapterCount, (i) => 'Ch ${i + 1}'),
);

Map<int, ReaderChapter> _singleChapter(List<ReaderBlock> blocks) => {
  0: ReaderChapter(index: 0, title: 'Chapter', blocks: blocks),
};

const _continuous = ReaderSettings(mode: ReaderMode.continuous);

void main() {
  group('lazy chapter rendering', () {
    testWidgets('single block renders correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _singleChapter([
              const ReaderBlock(index: 0, text: 'Hello world'),
            ]),
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello world'), findsOneWidget);
    });

    testWidgets('inner ListView.builder has correct properties', (
      WidgetTester tester,
    ) async {
      final blocks = List.generate(
        5,
        (i) => ReaderBlock(index: i, text: 'B $i'),
      );
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _singleChapter(blocks),
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViews = tester.widgetList<ListView>(find.byType(ListView)).toList();
      final inner = listViews.where((lv) => lv.shrinkWrap).toList();
      expect(inner, hasLength(1));
      expect(inner.first.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('empty chapter renders without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: const {
              0: ReaderChapter(index: 0, title: 'Empty', blocks: []),
            },
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('scrolling reveals more blocks', (WidgetTester tester) async {
      final blocks = List.generate(
        100,
        (i) => ReaderBlock(index: i, text: 'P $i'),
      );
      final controller = ScrollController();
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _singleChapter(blocks),
            settings: _continuous,
            scrollController: controller,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('P 0'), findsOneWidget);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.textContaining('P 99'), findsOneWidget);
    });

    testWidgets('multiple chapters each get their own inner ListView', (
      WidgetTester tester,
    ) async {
      final blocks1 = List.generate(3, (i) => ReaderBlock(index: i, text: 'A$i'));
      final blocks2 = List.generate(3, (i) => ReaderBlock(index: i, text: 'B$i'));
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(chapterCount: 2),
            loadedChapters: {
              0: ReaderChapter(index: 0, title: 'Ch1', blocks: blocks1),
              1: ReaderChapter(index: 1, title: 'Ch2', blocks: blocks2),
            },
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listViews = tester.widgetList<ListView>(find.byType(ListView)).toList();
      final inner = listViews.where((lv) => lv.shrinkWrap).toList();
      expect(inner.length, greaterThanOrEqualTo(1));
    });
  });
}
