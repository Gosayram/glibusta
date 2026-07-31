import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(width: 400, height: 800, child: child),
    ),
  );
}

NormalizedBookMetadata _meta({int chapterCount = 3}) => NormalizedBookMetadata(
  id: 'test',
  title: 'Test Book',
  authors: const [],
  chapterCount: chapterCount,
  chapterTitles: List.generate(chapterCount, (i) => 'Chapter ${i + 1}'),
);

ReaderChapter _chapter(String title, {int blockCount = 3}) => ReaderChapter(
  index: 0,
  title: title,
  blocks: List.generate(
    blockCount,
    (i) => ReaderBlock(text: 'Paragraph $i of $title', index: i),
  ),
);

const _continuous = ReaderSettings(mode: ReaderMode.continuous);

void main() {
  group('LITHIUM-READ-010 loading indicator between chapters', () {
    testWidgets('shows spinner when next chapter is not loaded', (tester) async {
      final loaded = {0: _chapter('Chapter 1')};
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: loaded,
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows divider text when next chapter is loaded', (tester) async {
      final loaded = {
        0: _chapter('Chapter 1'),
        1: _chapter('Chapter 2'),
      };
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: loaded,
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Chapter 2'), findsWidgets);
    });

    testWidgets('no spinner after last chapter (end of book)', (tester) async {
      final loaded = {
        0: _chapter('Chapter 1'),
        1: _chapter('Chapter 2'),
        2: _chapter('Chapter 3'),
      };
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: loaded,
            settings: _continuous,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('scroll position maintained when next chapter appended', (tester) async {
      final controller = ScrollController();
      final loaded = <int, ReaderChapter>{
        0: _chapter('Chapter 1', blockCount: 20),
      };
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: loaded,
            settings: _continuous,
            scrollController: controller,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      controller.jumpTo(200);
      final offsetBefore = controller.offset;

      loaded[1] = _chapter('Chapter 2', blockCount: 10);
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: loaded,
            settings: _continuous,
            scrollController: controller,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(controller.offset, offsetBefore);
    });
  });

  group('LITHIUM-READ-010 resolveChapterAtViewportTop', () {
    test('resolves chapter at 80% scroll position', () {
      final positions = [0.0, 1000.0, 2500.0, 4000.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 3200,
          chapterPositions: positions,
          totalChapters: 4,
        ),
        2,
      );
    });

    test('resolves first chapter at start', () {
      final positions = [0.0, 1000.0, 2500.0];
      expect(
        ReaderController.resolveChapterAtViewportTop(
          scrollOffset: 0,
          chapterPositions: positions,
          totalChapters: 3,
        ),
        0,
      );
    });
  });
}
