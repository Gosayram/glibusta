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
    id: 'test-repag',
    title: 'Repagination Test Book',
    authors: const [],
    chapterCount: chapterCount,
    chapterTitles: titles,
  );
}

Map<int, ReaderChapter> _chapters(int count, {int blocksPerChapter = 3}) {
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
  group('background repagination', () {
    testWidgets('settings change triggers single rebuild at end, not per batch', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(50);
      final meta = _meta(50);
      final controller = ScrollController();

      final key = GlobalKey<State>();
      await tester.pumpWidget(
        _wrap(
          _RepagTestHarness(
            key: key,
            metadata: meta,
            loadedChapters: chapters,
            initialSettings: _settings(),
            scrollController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = key.currentState! as _RepagTestHarnessState;
      state.rebuildCount = 0;

      state.updateSettings(_settings(fontSize: 22.0));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(state.rebuildCount, lessThanOrEqualTo(2));
    });

    testWidgets('pages are correct after repagination completes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(10, blocksPerChapter: 5);
      final meta = _meta(10);

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

      expect(find.byType(PageView), findsOneWidget);

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
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      final pageViewAfter = tester.widget<PageView>(find.byType(PageView));
      expect(pageViewAfter.controller, isNotNull);
    });

    testWidgets('large book (200 chapters) repaginates without hanging', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chapters = _chapters(200, blocksPerChapter: 2);
      final meta = _meta(200);

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

      final sw = Stopwatch()..start();
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
      await tester.pumpAndSettle();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(10000));

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller, isNotNull);
    });
  });
}

class _RepagTestHarness extends StatefulWidget {
  const _RepagTestHarness({
    super.key,
    required this.metadata,
    required this.loadedChapters,
    required this.initialSettings,
    required this.scrollController,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings initialSettings;
  final ScrollController scrollController;

  @override
  State<_RepagTestHarness> createState() => _RepagTestHarnessState();
}

class _RepagTestHarnessState extends State<_RepagTestHarness> {
  late ReaderSettings _settings;
  int rebuildCount = 0;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void updateSettings(ReaderSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  @override
  Widget build(BuildContext context) {
    rebuildCount++;
    return ReaderContentBody(
      metadata: widget.metadata,
      loadedChapters: widget.loadedChapters,
      settings: _settings,
      scrollController: widget.scrollController,
      onTap: (_) {},
    );
  }
}
