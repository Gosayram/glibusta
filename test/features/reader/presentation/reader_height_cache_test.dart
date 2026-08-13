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
    id: 'test-height-cache',
    title: 'Test Book',
    authors: const [],
    chapterCount: chapterCount,
    chapterTitles: titles,
  );
}

Map<int, ReaderChapter> _chapters(
  int count, {
  int blocksPerChapter = 15,
  String suffix = '',
}) {
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
              'Paragraph ${j + 1}$suffix. '
              'Some filler text to ensure the block has measurable height. '
              'The quick brown fox jumps over the lazy dog.',
        ),
      ),
    );
  }
  return result;
}

ReaderSettings _settings({double fontSize = 18.0}) => ReaderSettings(fontSize: fontSize);

void main() {
  group('height cache persistence', () {
    testWidgets('height cache survives loadedChapters change — no repagination', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meta = _meta(5);
      final chapters = _chapters(5);

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

      final updatedChapters = Map<int, ReaderChapter>.from(chapters);
      updatedChapters[3] = ReaderChapter(
        index: 3,
        title: 'Chapter 4',
        blocks: List.generate(
          15,
          (j) => ReaderBlock(
            index: j,
            text:
                'New paragraph ${j + 1}. '
                'Updated content for chapter 4. '
                'The quick brown fox jumps over the lazy dog.',
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: updatedChapters,
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('height cache clears when settings change — triggers repagination', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meta = _meta(5);
      final chapters = _chapters(5);

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

    testWidgets('adding a new chapter does not force full re-pagination', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final meta = _meta(3);
      final chapters = _chapters(3);

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

      final newMeta = _meta(4);
      final expandedChapters = Map<int, ReaderChapter>.from(chapters);
      expandedChapters[3] = ReaderChapter(
        index: 3,
        title: 'Chapter 4',
        blocks: List.generate(
          15,
          (j) => ReaderBlock(
            index: j,
            text:
                'Brand new chapter 4 paragraph ${j + 1}. '
                'The quick brown fox jumps over the lazy dog.',
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: newMeta,
            loadedChapters: expandedChapters,
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
