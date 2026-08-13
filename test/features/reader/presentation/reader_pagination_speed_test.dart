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

NormalizedBookMetadata _multiChapterMeta(int chapterCount) {
  final titles = List.generate(chapterCount, (i) => 'Chapter ${i + 1}');
  return NormalizedBookMetadata(
    id: 'test-pagination',
    title: 'Test Book',
    authors: const [],
    chapterCount: chapterCount,
    chapterTitles: titles,
  );
}

Map<int, ReaderChapter> _multiChapters(int count, {int blocksPerChapter = 20}) {
  final chapters = <int, ReaderChapter>{};
  for (var i = 0; i < count; i++) {
    chapters[i] = ReaderChapter(
      index: i,
      title: 'Chapter ${i + 1}',
      blocks: List.generate(
        blocksPerChapter,
        (j) => ReaderBlock(
          index: j,
          text:
              'Paragraph ${j + 1} in chapter ${i + 1}. '
              'This is a longer text block to ensure pagination has work to do. '
              'The quick brown fox jumps over the lazy dog repeatedly.',
        ),
      ),
    );
  }
  return chapters;
}

ReaderSettings _settings({double fontSize = 18.0}) => ReaderSettings(fontSize: fontSize);

void main() {
  group('LITHIUM-UNKNOWN-005 pagination speed', () {
    testWidgets('changing settings triggers re-pagination and shows progress', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _multiChapters(10);
      final meta = _multiChapterMeta(10);

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

      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(fontSize: 24.0),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('repagination completes and pages are correct', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _multiChapters(5, blocksPerChapter: 10);
      final meta = _multiChapterMeta(5);

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

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(fontSize: 20.0),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('current chapter content is visible immediately after settings change', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _multiChapters(10, blocksPerChapter: 5);
      final meta = _multiChapterMeta(10);

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

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: chapters,
            settings: _settings(fontSize: 22.0),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('no repagination when settings unchanged', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _multiChapters(5);
      final meta = _multiChapterMeta(5);

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
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
