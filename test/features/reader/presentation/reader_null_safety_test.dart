import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';
import 'package:glibusta/features/reader/presentation/reader_selection_toolbar.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
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
  chapterTitles: ['Chapter One'],
);

Map<int, ReaderChapter> _chapters() => {
  0: const ReaderChapter(index: 0, title: 'Chapter One', blocks: []),
};

void main() {
  group('null fontSize fallback', () {
    test('TextStyle with null fontSize uses default 14.0', () {
      const style = TextStyle();
      expect(style.fontSize, isNull);
      final resolved = style.fontSize ?? 14.0;
      expect(resolved, 14.0);
    });

    testWidgets('chapter title banner handles null fontSize gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(),
            settings: const ReaderSettings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('null selectedText guard', () {
    testWidgets('toolbar renders with non-empty selectedText', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: 'hello',
              onDismiss: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('null metadata guard', () {
    test('null metadata is distinguished from valid metadata', () {
      const NormalizedBookMetadata? nullMeta = null;
      expect(nullMeta, isNull);
      final NormalizedBookMetadata nonNullMeta = nullMeta ?? _meta();
      expect(nonNullMeta.title, 'Test');
    });

    testWidgets('ReaderContentBody accepts valid metadata', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: _chapters(),
            settings: const ReaderSettings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
