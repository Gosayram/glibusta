import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: 400, height: 800, child: child),
    ),
  );
}

const _metadata = NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: [],
  chapterCount: 1,
  chapterTitles: ['Chapter One'],
);

final _loadedChapters = <int, ReaderChapter>{
  0: const ReaderChapter(
    index: 0,
    title: 'Chapter One',
    blocks: [
      ReaderBlock(index: 0, text: 'First paragraph'),
      ReaderBlock(index: 1, text: 'Second paragraph'),
    ],
  ),
};

const _readerSettings = ReaderSettings(mode: ReaderMode.focus);

void main() {
  group('_FocusModeBody PageController lifecycle', () {
    testWidgets('creates PageController once and reuses across rebuilds', (
      WidgetTester tester,
    ) async {
      final notifier = ValueNotifier(0);
      await tester.pumpWidget(
        _wrap(
          ValueListenableBuilder(
            valueListenable: notifier,
            builder: (context, _, child) => ReaderContentBody(
              metadata: _metadata,
              loadedChapters: _loadedChapters,
              settings: _readerSettings,
              scrollController: ScrollController(),
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller1 = pageView.controller;

      notifier.value++;
      await tester.pumpAndSettle();

      final pageView2 = tester.widget<PageView>(find.byType(PageView));
      final controller2 = pageView2.controller;

      expect(controller1, same(controller2));
    });

    testWidgets('disposes PageController when widget is removed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _metadata,
            loadedChapters: _loadedChapters,
            settings: _readerSettings,
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;

      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(controller.hasClients, isFalse);
    });
  });
}
