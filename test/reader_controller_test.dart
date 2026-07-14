import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content_helper.dart';
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

  group('ReaderState', () {
    test('default values are correct', () {
      final state = ReaderState();
      expect(state.metadata, isNull);
      expect(state.isLoading, isTrue);
      expect(state.loadingStage, ReaderLoadingStage.openingFile);
      expect(state.loadingMessage, 'Открытие файла...');
      expect(state.errorMessage, isNull);
      expect(state.errorFilePath, isNull);
      expect(state.errorFormat, isNull);
      expect(state.errorFileSize, isNull);
      expect(state.currentPosition, ReaderPosition.initial);
      expect(state.uiVisible, isTrue);
      expect(state.isBottomSheetOpen, isFalse);
      expect(state.scrollProgress, 0.0);
      expect(state.estimatedMinutesLeft, 0);
      expect(state.isSearchOpen, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final state = ReaderState(
        loadingStage: null,
        errorMessage: 'error',
        errorFilePath: '/path/to/file.epub',
        errorFormat: 'epub',
        errorFileSize: 1024,
        scrollProgress: 0.5,
        estimatedMinutesLeft: 30,
      );
      final updated = state.copyWith(loadingStage: ReaderLoadingStage.readingMetadata);
      expect(updated.isLoading, isTrue);
      expect(updated.loadingStage, ReaderLoadingStage.readingMetadata);
      expect(updated.errorMessage, 'error');
      expect(updated.errorFilePath, '/path/to/file.epub');
      expect(updated.errorFormat, 'epub');
      expect(updated.errorFileSize, 1024);
      expect(updated.scrollProgress, 0.5);
      expect(updated.estimatedMinutesLeft, 30);
    });

    test('copyWith updates specified fields', () {
      final state = ReaderState();
      final updated = state.copyWith(
        clearLoadingStage: true,
        errorMessage: 'test error',
        errorFilePath: '/test.epub',
        errorFormat: 'epub',
        errorFileSize: 2048,
        isSearchOpen: true,
      );
      expect(updated.isLoading, isFalse);
      expect(updated.loadingStage, isNull);
      expect(updated.errorMessage, 'test error');
      expect(updated.errorFilePath, '/test.epub');
      expect(updated.errorFormat, 'epub');
      expect(updated.errorFileSize, 2048);
      expect(updated.isSearchOpen, isTrue);
    });

    test('copyWith with currentPosition updates position', () {
      final state = ReaderState();
      final position = ReaderPosition(
        bookId: 'book1',
        chapterIndex: 3,
        paragraphIndex: 5,
        localOffset: 2.5,
        progressPercent: 0.45,
        updatedAt: DateTime(2026),
      );
      final updated = state.copyWith(currentPosition: position);
      expect(updated.currentPosition.chapterIndex, 3);
      expect(updated.currentPosition.paragraphIndex, 5);
      expect(updated.currentPosition.progressPercent, 0.45);
    });

    test('copyWith error fields can be set', () {
      final state = ReaderState();
      final updated = state.copyWith(
        errorFilePath: '/book.epub',
        errorFormat: 'fb2',
        errorFileSize: 512000,
      );
      expect(updated.errorFilePath, '/book.epub');
      expect(updated.errorFormat, 'fb2');
      expect(updated.errorFileSize, 512000);
    });

    test('ReaderState copyWith chain produces expected state', () {
      final state = ReaderState();
      final updated = state
          .copyWith(clearLoadingStage: true)
          .copyWith(errorMessage: 'err')
          .copyWith(isSearchOpen: true);
      expect(updated.isLoading, isFalse);
      expect(updated.errorMessage, 'err');
      expect(updated.isSearchOpen, isTrue);
    });

    test('ReaderState inequality differs', () {
      final a = ReaderState(loadingStage: null);
      final b = ReaderState(isSearchOpen: true);
      expect(a.isSearchOpen, isNot(equals(b.isSearchOpen)));
    });

    test('collection state cannot be mutated after publication', () {
      final checkpoints = <double>[0.25];
      final state = ReaderState(checkpoints: checkpoints);

      checkpoints.add(0.75);

      expect(state.checkpoints, <double>[0.25]);
      expect(state.loadedChapters.clear, throwsUnsupportedError);
      expect(() => state.checkpoints.add(0.5), throwsUnsupportedError);
    });

    test('word count ignores empty and whitespace-only blocks', () {
      final chapters = <ReaderChapter>[
        const ReaderChapter(
          index: 0,
          title: 'Chapter',
          blocks: [
            ReaderBlock(index: 0, text: '  two\twords  '),
            ReaderBlock(index: 1, text: ''),
            ReaderBlock(index: 2, text: '\n  '),
          ],
        ),
      ];

      expect(ReaderContentHelper.countWords(chapters), 2);
    });
  });

  group('ReaderController', () {
    Future<ReaderController> createController(WidgetTester tester, String bookId) async {
      late ReaderController ctrl;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        final refProvider = Provider<ReaderController>((ref) {
          return ReaderController(bookId, ref);
        });
        ctrl = container.read(refProvider);
      });
      return ctrl;
    }

    testWidgets('toggleSearch toggles isSearchOpen', (tester) async {
      final ctrl = await createController(tester, 'book1');
      expect(ctrl.state.isSearchOpen, isFalse);
      ctrl.toggleSearch();
      expect(ctrl.state.isSearchOpen, isTrue);
      ctrl.toggleSearch();
      expect(ctrl.state.isSearchOpen, isFalse);
      ctrl.dispose();
    });

    testWidgets('closeSearch sets isSearchOpen to false', (tester) async {
      final ctrl = await createController(tester, 'book1');
      ctrl.toggleSearch();
      expect(ctrl.state.isSearchOpen, isTrue);
      ctrl.closeSearch();
      expect(ctrl.state.isSearchOpen, isFalse);
      ctrl.dispose();
    });

    testWidgets('toggleUi toggles uiVisible', (tester) async {
      final ctrl = await createController(tester, 'book1');
      expect(ctrl.state.uiVisible, isTrue);
      ctrl.toggleUi();
      expect(ctrl.state.uiVisible, isFalse);
      ctrl.toggleUi();
      expect(ctrl.state.uiVisible, isTrue);
      ctrl.dispose();
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('onBottomSheetOpen/close toggles isBottomSheetOpen', (tester) async {
      final ctrl = await createController(tester, 'book1');
      expect(ctrl.state.isBottomSheetOpen, isFalse);
      ctrl.onBottomSheetOpen();
      expect(ctrl.state.isBottomSheetOpen, isTrue);
      ctrl.onBottomSheetClose();
      expect(ctrl.state.isBottomSheetOpen, isFalse);
      ctrl.dispose();
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('buildDiagnostics contains book ID', (tester) async {
      final ctrl = await createController(tester, 'test-book-123');
      final diagnostics = ctrl.buildDiagnostics();
      expect(diagnostics, contains('test-book-123'));
      expect(diagnostics, contains('Diagnostics'));
      expect(diagnostics, contains('Platform:'));
      expect(diagnostics, contains('Chapters: 0'));
      ctrl.dispose();
    });

    testWidgets('deleteBookFile with no errorFilePath does nothing', (tester) async {
      final ctrl = await createController(tester, 'book1');
      await tester.runAsync(() => ctrl.deleteBookFile());
      expect(ctrl.state.errorMessage, isNull);
      ctrl.dispose();
    });

    testWidgets('dispose does not throw', (tester) async {
      final ctrl = await createController(tester, 'book1');
      expect(() => ctrl.dispose(), returnsNormally);
    });
  });
}
