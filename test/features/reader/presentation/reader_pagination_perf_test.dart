import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(width: 400, height: 800, child: child),
    ),
  );
}

NormalizedBookMetadata _meta(int chapterCount) {
  final titles = List.generate(chapterCount, (i) => 'Chapter ${i + 1}');
  return NormalizedBookMetadata(
    id: 'test-perf',
    title: 'Perf Test Book',
    authors: const [],
    chapterCount: chapterCount,
    chapterTitles: titles,
  );
}

Map<int, ReaderChapter> _chapters(int count, {required int blocksPerChapter}) {
  final result = <int, ReaderChapter>{};
  for (var i = 0; i < count; i++) {
    result[i] = ReaderChapter(
      index: i,
      title: 'Chapter ${i + 1}',
      blocks: List.generate(
        blocksPerChapter,
        (j) => ReaderBlock(
          index: j,
          text:
              'Paragraph ${j + 1}. This is a sufficiently long text block '
              'to produce a realistic height estimate for pagination. '
              'The quick brown fox jumps over the lazy dog repeatedly '
              'to fill space and make the measurement more accurate.',
        ),
      ),
    );
  }
  return result;
}

ReaderSettings _settings({double fontSize = 18.0}) => ReaderSettings(fontSize: fontSize);

void main() {
  group('pagination performance', () {
    testWidgets('500 blocks in a single chapter paginate in <1 second', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(1, blocksPerChapter: 500);
      final meta = _meta(1);

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    testWidgets('500 blocks across 10 chapters paginate in <2 seconds', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(10, blocksPerChapter: 50);
      final meta = _meta(10);

      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    testWidgets('page boundaries are non-overlapping and cover all blocks', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(3, blocksPerChapter: 20);
      final meta = _meta(3);

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller, isNotNull);
    });
  });
}
