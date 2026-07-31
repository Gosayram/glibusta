import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.light(),
  home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
);

NormalizedBookMetadata _metaWithFonts(Map<String, String> fonts) => NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: const [],
  chapterCount: 1,
  chapterTitles: const ['Chapter'],
  metadata: {'fonts': fonts},
);

const _metaWithoutFonts = NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: [],
  chapterCount: 1,
  chapterTitles: ['Chapter'],
);

Map<int, ReaderChapter> _chapters({List<ReaderBlock> blocks = const []}) => {
  0: ReaderChapter(index: 0, title: 'Chapter', blocks: blocks),
};

void main() {
  group('embedded font family extraction', () {
    test('extracts first font family from metadata', () {
      final meta = _metaWithFonts({
        'MyCustomFont': '../Fonts/custom.woff2',
        'AnotherFont': '../Fonts/another.woff2',
      });
      final fonts = meta.metadata?['fonts'] as Map?;
      expect(fonts, isNotNull);
      expect(fonts!.keys.first, 'MyCustomFont');
    });

    test('returns null when no fonts in metadata', () {
      expect(_metaWithoutFonts.metadata?['fonts'], isNull);
    });

    test('returns null when fonts map is empty', () {
      final meta = _metaWithFonts({});
      final fonts = meta.metadata?['fonts'] as Map?;
      expect(fonts, isNotNull);
      expect(fonts!.isEmpty, isTrue);
    });
  });

  group('ReaderCtx embedded font', () {
    test('passes embeddedFontFamily when metadata has fonts', () {
      const ctx = ReaderCtx(
        settings: ReaderSettings(),
        linkColor: Colors.blue,
        brightness: Brightness.light,
        embeddedFontFamily: 'BookFont',
      );
      expect(ctx.embeddedFontFamily, 'BookFont');
    });

    test('embeddedFontFamily is null when no embedded fonts', () {
      const ctx = ReaderCtx(
        settings: ReaderSettings(),
        linkColor: Colors.blue,
        brightness: Brightness.light,
      );
      expect(ctx.embeddedFontFamily, isNull);
    });
  });

  group('embedded font in reader content', () {
    testWidgets('book with embedded fonts renders without error', (
      WidgetTester tester,
    ) async {
      final meta = _metaWithFonts({'BookFont': '../Fonts/book.woff2'});
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: _chapters(),
            settings: const ReaderSettings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderContentBody), findsOneWidget);
    });

    testWidgets('book without embedded fonts renders without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _metaWithoutFonts,
            loadedChapters: _chapters(),
            settings: const ReaderSettings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderContentBody), findsOneWidget);
    });

    testWidgets('user font choice overrides embedded font', (
      WidgetTester tester,
    ) async {
      final meta = _metaWithFonts({'BookFont': '../Fonts/book.woff2'});
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: meta,
            loadedChapters: _chapters(
              blocks: [const ReaderBlock(index: 0, text: 'Hello world')],
            ),
            settings: const ReaderSettings(font: ReaderFont.inter),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderContentBody), findsOneWidget);
    });
  });
}
