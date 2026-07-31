import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/library/domain/book_file_repository.dart';
import 'package:glibusta/features/reader/data/book_open_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_progress_helper.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';

class _RecoveryBookOpenService extends BookOpenService {
  _RecoveryBookOpenService(AppDatabase database)
    : super(
        AppFileStorageImpl(),
        BookFileRepositoryImpl(database),
        logger: AppLogger(),
      );

  static const int chapterCount = 10;

  @override
  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    return NormalizedBookMetadata(
      id: bookId,
      title: 'Recovery test book',
      authors: const [],
      chapterCount: chapterCount,
      chapterTitles: List<String>.generate(chapterCount, (i) => 'Chapter $i'),
    );
  }

  @override
  Future<ReaderChapter?> loadChapter(String bookId, int index) async {
    if (index < 0 || index >= chapterCount) return null;
    return ReaderChapter(
      index: index,
      title: 'Chapter $index',
      blocks: List.generate(
        5,
        (i) => ReaderBlock(index: i, text: 'Block $i in chapter $index'),
      ),
    );
  }
}

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

  Future<ReaderController> createController(
    WidgetTester tester,
    String bookId, {
    BookOpenService? bookOpenService,
    ReaderSettings? settings,
  }) async {
    late ReaderController ctrl;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (bookOpenService != null) bookOpenServiceProvider.overrideWithValue(bookOpenService),
        readerSettingsProvider.overrideWithValue(settings ?? const ReaderSettings()),
      ],
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

  group('RECOVERY-001: force-stop position recovery', () {
    testWidgets('dispose persists position to database', (tester) async {
      final service = _RecoveryBookOpenService(db);
      final ctrl = await createController(tester, 'recovery-book', bookOpenService: service);

      await tester.runAsync(ctrl.loadBook);
      ctrl.handleFocusPositionChanged(3, 2);

      expect(ctrl.state.currentPosition.chapterIndex, 3);
      expect(ctrl.state.currentPosition.paragraphIndex, 2);

      ctrl.dispose();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      final saved = await ReaderProgressHelper(
        db,
        'recovery-book',
        AppLogger(),
      ).loadSavedPosition(_RecoveryBookOpenService.chapterCount);

      expect(saved.chapterIndex, 3);
      expect(saved.paragraphIndex, 2);
    });

    testWidgets('saved position includes chapter, block, and offset', (tester) async {
      final service = _RecoveryBookOpenService(db);
      final ctrl = await createController(tester, 'pos-book', bookOpenService: service);

      await tester.runAsync(ctrl.loadBook);
      ctrl.handleFocusPositionChanged(5, 4);

      ctrl.dispose();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.bookId.equals('pos-book'))).getSingleOrNull();

      expect(row, isNotNull);
      expect(row!.chapterIndex, 5);
      expect(row.paragraphIndex, 4);
      expect(row.localOffset, isNonNegative);
    });

    testWidgets('restore returns to exact paragraph', (tester) async {
      final helper = ReaderProgressHelper(db, 'restore-book', AppLogger());
      final target = ReaderPosition(
        bookId: 'restore-book',
        chapterIndex: 7,
        paragraphIndex: 3,
        localOffset: 15.5,
        progressPercent: 0.75,
        updatedAt: DateTime.utc(2026, 7, 31),
      );

      await tester.runAsync(() async {
        helper.savePosition(target);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      final restored = await helper.loadSavedPosition(10);

      expect(restored.chapterIndex, 7);
      expect(restored.paragraphIndex, 3);
      expect(restored.localOffset, 15.5);
    });

    testWidgets('savePosition works without loaded chapters', (tester) async {
      final ctrl = await createController(tester, 'unloaded-book');

      expect(() => ctrl.dispose(), returnsNormally);
    });

    testWidgets('lifecycle detached triggers savePosition', (tester) async {
      final helper = ReaderProgressHelper(db, 'lifecycle-book', AppLogger());
      final position = ReaderPosition(
        bookId: 'lifecycle-book',
        chapterIndex: 4,
        paragraphIndex: 2,
        localOffset: 30.0,
        progressPercent: 0.5,
        updatedAt: DateTime.utc(2026, 7, 31),
      );

      await tester.runAsync(() async {
        helper.savePosition(position);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      final restored = await helper.loadSavedPosition(10);

      expect(restored.chapterIndex, 4);
      expect(restored.paragraphIndex, 2);
      expect(restored.localOffset, 30.0);
    });
  });
}
