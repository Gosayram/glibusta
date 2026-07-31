import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (Object? message) async => const StandardMessageCodec().encodeMessage(<Object?>[]),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ReaderState multi-page highlight', () {
    test('default highlightMode is idle', () {
      final state = ReaderState();
      expect(state.highlightMode, HighlightSelectionMode.idle);
      expect(state.multiHighlightStartChapter, isNull);
      expect(state.multiHighlightStartParagraph, isNull);
      expect(state.multiHighlightStartText, isNull);
    });

    test('copyWith sets highlight mode to startSet', () {
      final state = ReaderState();
      final updated = state.copyWith(
        highlightMode: HighlightSelectionMode.startSet,
        multiHighlightStartChapter: 2,
        multiHighlightStartParagraph: 5,
        multiHighlightStartText: 'Start text',
      );
      expect(updated.highlightMode, HighlightSelectionMode.startSet);
      expect(updated.multiHighlightStartChapter, 2);
      expect(updated.multiHighlightStartParagraph, 5);
      expect(updated.multiHighlightStartText, 'Start text');
    });

    test('copyWith clearMultiHighlightStart resets all start fields', () {
      final state = ReaderState(
        highlightMode: HighlightSelectionMode.startSet,
        multiHighlightStartChapter: 2,
        multiHighlightStartParagraph: 5,
        multiHighlightStartText: 'Start text',
      );
      final cleared = state.copyWith(
        highlightMode: HighlightSelectionMode.idle,
        clearMultiHighlightStart: true,
      );
      expect(cleared.highlightMode, HighlightSelectionMode.idle);
      expect(cleared.multiHighlightStartChapter, isNull);
      expect(cleared.multiHighlightStartParagraph, isNull);
      expect(cleared.multiHighlightStartText, isNull);
    });
  });

  group('ReaderController multi-page highlight', () {
    Future<ReaderController> createController(WidgetTester tester) async {
      late ReaderController ctrl;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        final refProvider = Provider<ReaderController>((ref) {
          return ReaderController('test-book', ref);
        });
        ctrl = container.read(refProvider);
      });
      return ctrl;
    }

    testWidgets('setMultiHighlightStart transitions idle → startSet and stores position', (
      tester,
    ) async {
      final ctrl = await createController(tester);
      expect(ctrl.state.highlightMode, HighlightSelectionMode.idle);

      ctrl.setMultiHighlightStart(3, 7, 'Beginning of selection');

      expect(ctrl.state.highlightMode, HighlightSelectionMode.startSet);
      expect(ctrl.state.multiHighlightStartChapter, 3);
      expect(ctrl.state.multiHighlightStartParagraph, 7);
      expect(ctrl.state.multiHighlightStartText, 'Beginning of selection');
      ctrl.dispose();
    });

    testWidgets('cancelMultiHighlight resets to idle and clears start', (tester) async {
      final ctrl = await createController(tester);
      ctrl.setMultiHighlightStart(3, 7, 'Some text');
      expect(ctrl.state.highlightMode, HighlightSelectionMode.startSet);

      ctrl.cancelMultiHighlight();

      expect(ctrl.state.highlightMode, HighlightSelectionMode.idle);
      expect(ctrl.state.multiHighlightStartChapter, isNull);
      expect(ctrl.state.multiHighlightStartParagraph, isNull);
      expect(ctrl.state.multiHighlightStartText, isNull);
      ctrl.dispose();
    });

    testWidgets('finishMultiHighlight inserts a highlight and resets to idle', (tester) async {
      final ctrl = await createController(tester);
      ctrl.setMultiHighlightStart(1, 2, 'First part');

      await tester.runAsync(() async {
        await ctrl.finishMultiHighlight(
          bookId: 'test-book',
          endChapterIndex: 4,
          endParagraphIndex: 9,
          endSelectedText: 'Second part',
        );
      });

      expect(ctrl.state.highlightMode, HighlightSelectionMode.idle);
      expect(ctrl.state.multiHighlightStartChapter, isNull);

      final highlights = await (db.select(
        db.textHighlights,
      )..where((h) => h.bookId.equals('test-book'))).get();
      expect(highlights, hasLength(1));
      expect(highlights.first.chapterIndex, 1);
      expect(highlights.first.blockIndex, 2);
      expect(highlights.first.selectedText, 'First part\n\nSecond part');
      expect(highlights.first.startOffset, 0);
      expect(highlights.first.endOffset, 'First part\n\nSecond part'.length);
      ctrl.dispose();
    });

    testWidgets('finishMultiHighlight does nothing when start is not set', (tester) async {
      final ctrl = await createController(tester);
      expect(ctrl.state.highlightMode, HighlightSelectionMode.idle);

      await tester.runAsync(() async {
        await ctrl.finishMultiHighlight(
          bookId: 'test-book',
          endChapterIndex: 0,
          endParagraphIndex: 0,
          endSelectedText: 'Some text',
        );
      });

      final highlights = await (db.select(
        db.textHighlights,
      )..where((h) => h.bookId.equals('test-book'))).get();
      expect(highlights, isEmpty);
      ctrl.dispose();
    });
  });
}
