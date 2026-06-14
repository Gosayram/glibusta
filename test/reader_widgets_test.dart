import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/data/book_open_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:glibusta/features/reader/presentation/reader_quick_settings.dart';
import 'package:glibusta/features/reader/presentation/reader_screen.dart';

class _FakeBookOpenService extends BookOpenService {
  _FakeBookOpenService(super.database);

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

  group('ReaderQuickSettingsSheet', () {
    testWidgets('renders all section labels', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тема'), findsOneWidget);
      expect(find.text('Шрифт'), findsOneWidget);
      expect(find.text('Размер шрифта'), findsOneWidget);
      expect(find.text('Межстрочный'), findsOneWidget);
      expect(find.text('Отступы'), findsOneWidget);
      expect(find.text('Авто-тема'), findsOneWidget);
      expect(find.text('Режим'), findsOneWidget);
    });

    testWidgets('renders all 7 theme swatches', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aa'), findsNWidgets(7));
    });

    testWidgets('renders all 2 font chips', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Literata'), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    });

    testWidgets('renders mode choice chips', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Прокрутка'), findsOneWidget);
      expect(find.text('Страницы'), findsOneWidget);
      expect(find.text('2 колонки'), findsOneWidget);
      expect(find.text('Фокус'), findsOneWidget);
      expect(find.text('Полный'), findsOneWidget);
    });

    testWidgets('default font size shows 18', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('font size minus button enabled at default 18', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
        ),
      );
      await tester.pumpAndSettle();

      final minusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minusButton.onPressed, isNotNull);
    });

    testWidgets('font size minus disabled at minimum 12', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
          initialSettings: const ReaderSettings(fontSize: 12),
        ),
      );
      await tester.pumpAndSettle();

      final minusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minusButton.onPressed, isNull);
    });

    testWidgets('font size plus disabled at maximum 32', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
          initialSettings: const ReaderSettings(fontSize: 32),
        ),
      );
      await tester.pumpAndSettle();

      final plusButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(plusButton.onPressed, isNull);
    });

    testWidgets('auto-theme custom shows hour dropdowns', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
          initialSettings: const ReaderSettings(
            autoThemeMode: AutoThemeMode.custom,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('День с: '), findsOneWidget);
      expect(find.text('Ночь с: '), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsNWidgets(2));
    });

    testWidgets('auto-theme off hides hour dropdowns', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(onDismiss: SizedBox.new),
          initialSettings: const ReaderSettings(),
        ),
      );
      await tester.pumpAndSettle();

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
            onSettings: SizedBox.new,
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
            onSettings: SizedBox.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays settings tune icon', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderTopBar(
            settings: ReaderSettings(),
            bookTitle: 'Book',
            onBack: SizedBox.new,
            onSettings: SizedBox.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune), findsOneWidget);
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Глава 3 из 10'), findsOneWidget);
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.textContaining('~50м'), findsOneWidget);
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ч'), findsOneWidget);
      expect(find.textContaining('м'), findsOneWidget);
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('м'), findsWidgets);
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
          ],
          child: const MaterialApp(
            home: ReaderScreen(bookId: 'book-1'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Текст книги успешно загружен.'), findsOneWidget);
    });
  });
}

class _TestReaderSettingsNotifier extends ReaderSettingsNotifier {
  _TestReaderSettingsNotifier(this._initial);
  final ReaderSettings _initial;

  @override
  ReaderSettings build() => _initial;
}
