import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: child,
      ),
    ),
  );
}

NormalizedBookMetadata _meta({String? coverUrl}) => NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: const [],
  coverUrl: coverUrl,
  chapterCount: 1,
  chapterTitles: const ['Chapter One'],
);

Map<int, ReaderChapter> _chapters({
  String title = 'Chapter One',
  List<ReaderBlock> blocks = const [],
}) => {
  0: ReaderChapter(
    index: 0,
    title: title,
    blocks: blocks,
  ),
};

ReaderSettings _settings() => const ReaderSettings();

void main() {
  group('LITHIUM-READ-009 chapter title banner', () {
    testWidgets('chapter title container has banner background decoration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(8),
      );
      expect(bannerFinder, findsOneWidget);
      final container = tester.widget<Container>(bannerFinder);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.border, isNotNull);
    });

    testWidgets('chapter title text is centered', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(8),
      );
      final texts = tester.widgetList<Text>(
        find.descendant(of: bannerFinder, matching: find.byType(Text)),
      );
      final centeredTexts = texts.where(
        (t) => t.textAlign == TextAlign.center,
      );
      expect(centeredTexts, isNotEmpty);
    });

    testWidgets('sub-heading (level 3) is NOT wrapped in banner style', (
      WidgetTester tester,
    ) async {
      final blocks = [
        const ReaderBlock(
          index: 0,
          text: 'Sub Heading',
          type: BlockType.heading,
          headingLevel: 3,
        ),
        const ReaderBlock(index: 1, text: 'Body text.'),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks: blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerContainers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(8),
      );
      expect(bannerContainers, findsOneWidget);

      final bannerTexts = tester.widgetList<Text>(
        find.descendant(
          of: bannerContainers,
          matching: find.byType(Text),
        ),
      );
      final hasSubHeading = bannerTexts.any(
        (t) => t.data?.contains('Sub Heading') == true,
      );
      expect(hasSubHeading, isFalse);
    });

    testWidgets('chapter title banner has bottom border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(8),
        ),
      );
      final withBorder = containers.where((c) {
        final d = c.decoration! as BoxDecoration;
        return d.border is Border && (d.border! as Border).bottom.width == 1;
      });
      expect(withBorder, isNotEmpty);
    });
  });

  group('LITHIUM-PAGE-004 inline image viewport constraints', () {
    testWidgets('image block has viewport-relative ConstrainedBox with ClipRect wrapper', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final blocks = [
        const ReaderBlock(
          index: 0,
          text: '',
          type: BlockType.image,
          imageUrl: '/fake/image.png',
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks: blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageConstrainedBox = find.byWidgetPredicate(
        (w) =>
            w is ConstrainedBox &&
            w.constraints.maxWidth == 400.0 &&
            w.constraints.maxHeight >= 559.0 &&
            w.constraints.maxHeight <= 561.0,
      );
      expect(imageConstrainedBox, findsOneWidget);

      final parent = find.ancestor(
        of: imageConstrainedBox,
        matching: find.byType(ClipRect),
      );
      expect(parent, findsWidgets);
    });

    testWidgets('image maxWidth is viewport width scaled by imageWidth setting', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final blocks = [
        const ReaderBlock(
          index: 0,
          text: '',
          type: BlockType.image,
          imageUrl: '/fake/image.png',
        ),
      ];
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(blocks: blocks),
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedBox = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth <= 400.0 && w.constraints.maxWidth > 0,
      );
      expect(constrainedBox, findsWidgets);

      final box = tester.widget<ConstrainedBox>(constrainedBox.first);
      expect(box.constraints.maxWidth, 400.0);
      expect(box.constraints.maxHeight, closeTo(560.0, 1.0));
    });
  });
}
