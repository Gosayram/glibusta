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

NormalizedBookMetadata _meta() => const NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: [],
  chapterCount: 1,
  chapterTitles: ['Chapter'],
);

ReaderSettings _settings() => const ReaderSettings();

Map<int, ReaderChapter> _chapters(List<ReaderBlock> blocks) => {
  0: ReaderChapter(index: 0, title: 'Chapter', blocks: blocks),
};

void main() {
  group('preformatted block', () {
    testWidgets('renders with monospace font', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'line one\nline two\nline three',
          type: BlockType.preformatted,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.byType(Text).last);
      expect(text.style?.fontFamily, 'monospace');
    });

    testWidgets('preserves line breaks in text', (tester) async {
      const content = 'first line\nsecond line\nthird line';
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: content,
          type: BlockType.preformatted,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == content,
      );
      expect(textFinder, findsOneWidget);
    });

    testWidgets('uses left alignment and softWrap false', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'code block',
          type: BlockType.preformatted,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == 'code block',
        ),
      );
      expect(text.textAlign, TextAlign.left);
      expect(text.softWrap, isFalse);
    });
  });

  group('poem/verse block', () {
    testWidgets('renders with italic style', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Roses are red\nViolets are blue',
          type: BlockType.poem,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data?.contains('Roses are red') == true,
        ),
      );
      expect(text.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('has bilateral indentation via padding', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Poem line',
          type: BlockType.poem,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.padding is EdgeInsetsDirectional &&
              (w.padding! as EdgeInsetsDirectional).start > 0 &&
              (w.padding! as EdgeInsetsDirectional).end > 0,
        ),
      );
      final padding = container.padding! as EdgeInsetsDirectional;
      expect(padding.start, greaterThan(0));
      expect(padding.end, greaterThan(0));
    });

    testWidgets('uses softWrap false to preserve line breaks', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Line one\nLine two',
          type: BlockType.poem,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data?.contains('Line one') == true,
        ),
      );
      expect(text.softWrap, isFalse);
    });

    testWidgets('respects block textAlign override', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Left aligned poem',
          type: BlockType.poem,
          textAlign: TextAlign.left,
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data?.contains('Left aligned poem') == true,
        ),
      );
      expect(text.textAlign, TextAlign.left);
    });
  });

  group('normal paragraph unaffected', () {
    testWidgets('renders without monospace or italic', (tester) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Just a normal paragraph.',
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextFinder = find.byWidgetPredicate((w) {
        if (w is! RichText) return false;
        final text = w.text;
        if (text is! TextSpan) return false;
        return text.toPlainText().contains('Just a normal paragraph.');
      });
      expect(richTextFinder, findsWidgets);
    });
  });
}
