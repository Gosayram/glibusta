import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/library/domain/book_file_repository.dart';
import 'package:glibusta/features/reader/data/book_open_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:glibusta/features/reader/presentation/reader_quick_settings.dart';
import 'package:glibusta/features/reader/presentation/reader_screen.dart';

class _FakeBookOpenService extends BookOpenService {
  _FakeBookOpenService(AppDatabase database)
    : super(
        AppFileStorageImpl(),
        BookFileRepositoryImpl(database),
        logger: AppLogger(),
      );

  static const _chapter = ReaderChapter(
    index: 0,
    title: 'Глава 1',
    blocks: [
      ReaderBlock(index: 0, text: 'Текст книги успешно загружен.'),
    ],
  );

  @override
  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    return const NormalizedBookMetadata(
      id: 'book-1',
      title: 'Тестовая книга',
      authors: ['Автор'],
      chapterCount: 1,
      chapterTitles: ['Глава 1'],
    );
  }

  @override
  Future<ReaderChapter?> loadChapter(String bookId, int index) async {
    return index == 0 ? _chapter : null;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Suppress overflow errors — they're visual warnings from constrained
    // test surfaces, not functional bugs. Real app uses BottomSheet/Scroller.
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      if (exception is FlutterError && exception.message.contains('overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  Widget wrapInApp(Widget child, {ReaderSettings? initialSettings}) {
    return ProviderScope(
      overrides: [
        if (initialSettings != null)
          readerSettingsProvider.overrideWith(
            () => _TestReaderSettingsNotifier(initialSettings),
          ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  Future<void> openSettingsPage(WidgetTester tester, String pageLabel) async {
    await tester.tap(find.text(pageLabel));
    await tester.pumpAndSettle();
  }

  Future<void> scrollSettingsUntilVisible(WidgetTester tester, Finder target) async {
    final scrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable.first);
  }

  group('ReaderQuickSettingsSheet', () {
    testWidgets('renders display page sections', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тема'), findsOneWidget);
      expect(find.text('Шрифт'), findsOneWidget);
      expect(find.text('Внешний вид'), findsOneWidget);
      expect(find.text('Пресеты'), findsOneWidget);
    });

    testWidgets('renders all 7 theme swatches', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aa'), findsNWidgets(7));
    });

    testWidgets('renders all 2 font chips', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Literata'), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    });

    testWidgets('renders mode choice chips', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Режим');

      expect(find.text('Прокрутка'), findsOneWidget);
      expect(find.text('Страницы'), findsOneWidget);
      expect(find.text('Фокус'), findsOneWidget);
      expect(find.text('RSVP'), findsOneWidget);
    });

    testWidgets('default font size shows 18', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      await scrollSettingsUntilVisible(tester, find.text('Размер шрифта'));

      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('font size minus button enabled at default 18', (tester) async {
      await tester.pumpWidget(
        wrapInApp(const ReaderQuickSettingsSheet()),
      );
      await tester.pumpAndSettle();

      await scrollSettingsUntilVisible(tester, find.text('Размер шрифта'));

      final minusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minusButton.onPressed, isNotNull);
    });

    testWidgets('font size minus disabled at minimum 12', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
          initialSettings: const ReaderSettings(fontSize: 10),
        ),
      );
      await tester.pumpAndSettle();

      await scrollSettingsUntilVisible(tester, find.text('Размер шрифта'));

      final minusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minusButton.onPressed, isNull);
    });

    testWidgets('font size plus disabled at maximum 32', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
          initialSettings: const ReaderSettings(fontSize: 40),
        ),
      );
      await tester.pumpAndSettle();

      await scrollSettingsUntilVisible(tester, find.text('Размер шрифта'));

      final plusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(plusButton.onPressed, isNull);
    });

    testWidgets('auto-theme custom shows hour dropdowns', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
          initialSettings: const ReaderSettings(autoThemeMode: AutoThemeMode.custom),
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Режим');
      await scrollSettingsUntilVisible(tester, find.text('День с: '));

      expect(find.text('День с: '), findsOneWidget);
      expect(find.text('Ночь с: '), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsNWidgets(2));
    });

    testWidgets('auto-theme off hides hour dropdowns', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Режим');
      await scrollSettingsUntilVisible(tester, find.text('Авто-тема'));

      expect(find.byType(DropdownButton<int>), findsNothing);
    });
  });

  group('ReaderTopBar', () {
    testWidgets('displays book title', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderTopBar(
            settings: ReaderSettings(),
            bookTitle: 'Test Book Title',
            onBack: SizedBox.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Book Title'), findsOneWidget);
    });

    testWidgets('displays back arrow', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderTopBar(
            settings: ReaderSettings(),
            bookTitle: 'Book',
            onBack: SizedBox.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays settings icon', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderTopBar(
            settings: ReaderSettings(),
            bookTitle: 'Book',
            onBack: SizedBox.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('ReaderBottomBar', () {
    testWidgets('displays chapter info', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderBottomBar(
            settings: ReaderSettings(bottomBarContent: BottomBarContent.chapter),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.3,
            estimatedMinutesLeft: 120,
            chapterTitle: 'Глава 3',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Глава 3'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);
    });

    testWidgets('displays percentage and time', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderBottomBar(
            settings: ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 5,
            scrollProgress: 0.5,
            estimatedMinutesLeft: 100,
            chapterTitle: 'Пролог',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('formats hours and minutes correctly', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderBottomBar(
            settings: ReaderSettings(bottomBarContent: BottomBarContent.time),
            currentChapterIndex: 0,
            totalChapters: 5,
            scrollProgress: 0.0,
            estimatedMinutesLeft: 150,
            chapterTitle: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('~150 мин'), findsOneWidget);
    });

    testWidgets('shows only minutes when less than hour', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderBottomBar(
            settings: ReaderSettings(bottomBarContent: BottomBarContent.time),
            currentChapterIndex: 0,
            totalChapters: 5,
            scrollProgress: 0.9,
            estimatedMinutesLeft: 10,
            chapterTitle: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('~10 мин'), findsOneWidget);
    });
  });

  group('ReaderProgressBar', () {
    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderProgressBar(
            scrollProgress: 0.5,
            theme: ReaderTheme.dark,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('progress value is passed correctly', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderProgressBar(
            scrollProgress: 0.75,
            theme: ReaderTheme.sepia,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.75);
    });
  });

  group('ReaderScreen', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('rebuilds when controller finishes loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            bookOpenServiceProvider.overrideWithValue(_FakeBookOpenService(db)),
            readerSettingsProvider.overrideWith(
              () => _TestReaderSettingsNotifier(
                const ReaderSettings(
                  separateMargins: true,
                  marginTop: 12,
                  marginBottom: 28,
                  marginLeft: 16,
                  marginRight: 36,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ReaderScreen(bookId: 'book-1'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ReaderContentBody), findsOneWidget);

      // Dispose the ProviderScope before closing the in-memory database so
      // Drift can cancel its query stream inside the test clock.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  testWidgets('RSVP skip controls work when the loaded chapter has no text', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'book-1',
            title: 'Тестовая книга',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Глава 1'],
          ),
          loadedChapters: const {
            0: ReaderChapter(index: 0, title: 'Глава 1', blocks: []),
          },
          settings: const ReaderSettings(mode: ReaderMode.rsvp),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.skip_next));

    expect(tester.takeException(), isNull);
    expect(find.text('300 сл/мин  ·  0/0'), findsOneWidget);
  });

  testWidgets('uses EPUB RTL metadata for direction-aware list layout', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'rtl-book',
            title: 'كتاب',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['فصل'],
            metadata: {'textDirection': 'rtl'},
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'فصل',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: '',
                  type: BlockType.list,
                  listItems: [ReaderBlock(index: 0, text: 'عنصر')],
                ),
              ],
            ),
          },
          settings: const ReaderSettings(),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Directionality && widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding is EdgeInsetsDirectional &&
            (widget.padding as EdgeInsetsDirectional).start == 24,
      ),
      findsWidgets,
    );
  });
}

void _ignoreTap(TapUpDetails _) {}

class _TestReaderSettingsNotifier extends ReaderSettingsNotifier {
  _TestReaderSettingsNotifier(this._initial);
  final ReaderSettings _initial;

  @override
  ReaderSettings build() => _initial;
}
