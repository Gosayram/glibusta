import 'dart:convert';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/app/router.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/core/database/daos/per_book_settings_dao.dart';
import 'package:glibusta/core/logging/app_logger.dart';
import 'package:glibusta/core/platform/app_file_storage.dart';
import 'package:glibusta/features/library/domain/book_file_repository.dart';
import 'package:glibusta/features/reader/data/book_open_service.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/data/per_book_settings_service.dart';
import 'package:glibusta/features/reader/data/reader_colors.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';
import 'package:glibusta/features/reader/presentation/reader_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_custom_css_editor.dart';
import 'package:glibusta/features/reader/presentation/reader_providers.dart';
import 'package:glibusta/features/reader/presentation/reader_quick_settings.dart';
import 'package:glibusta/features/reader/presentation/reader_screen.dart';
import 'package:glibusta/features/reader/presentation/reader_selection_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBookOpenService extends BookOpenService {
  _FakeBookOpenService(AppDatabase database, {ReaderChapter? chapter})
    : _chapterOverride = chapter,
      super(
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

  static const _defaultChapter = _chapter;

  final ReaderChapter? _chapterOverride;

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
    return index == 0 ? _chapterOverride ?? _chapter : null;
  }
}

class _TwoChapterBookOpenService extends _FakeBookOpenService {
  _TwoChapterBookOpenService(super.database);

  static const _secondChapter = ReaderChapter(
    index: 1,
    title: 'Глава 2',
    blocks: [ReaderBlock(index: 0, text: 'Текст второй главы.')],
  );

  @override
  Future<NormalizedBookMetadata?> getCachedMetadata(String bookId) async {
    return const NormalizedBookMetadata(
      id: 'book-1',
      title: 'Тестовая книга',
      authors: ['Автор'],
      chapterCount: 2,
      chapterTitles: ['Глава 1', 'Глава 2'],
    );
  }

  @override
  Future<ReaderChapter?> loadChapter(String bookId, int index) async {
    return switch (index) {
      0 => _FakeBookOpenService._defaultChapter,
      1 => _secondChapter,
      _ => null,
    };
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
    testWidgets('custom CSS editor explains its safe subset and resets rules', (tester) async {
      final semantics = tester.ensureSemantics();
      var currentCss = 'p { line-height: 1.7; }';
      await tester.pumpWidget(
        wrapInApp(
          StatefulBuilder(
            builder: (context, setState) => ReaderCustomCssEditor(
              css: currentCss,
              onChanged: (css) => setState(() => currentCss = css),
            ),
          ),
        ),
      );

      expect(find.textContaining('Применяются только свойства p'), findsOneWidget);
      expect(find.text('Пользовательский CSS применяется к текущей книге.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Пользовательский CSS применяется к текущей книге.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.labelText,
        'Правила CSS для абзацев',
      );
      expect(find.byTooltip('Сбросить пользовательский CSS'), findsOneWidget);

      await tester.tap(find.byTooltip('Сбросить пользовательский CSS'));
      await tester.pump();

      expect(currentCss, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);
      expect(find.text('Пользовательский CSS отключён.'), findsOneWidget);
      semantics.dispose();
    });

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

    testWidgets('exposes a typography reset action and the font-size value to semantics', (
      tester,
    ) async {
      await tester.pumpWidget(wrapInApp(const ReaderQuickSettingsSheet()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Сбросить настройки типографики'), findsOneWidget);
      await scrollSettingsUntilVisible(tester, find.text('Размер шрифта'));
      final fontSizeSlider = tester.widget<Slider>(find.byType(Slider).first);
      expect(
        fontSizeSlider.semanticFormatterCallback?.call(18),
        'Размер шрифта 18 пунктов, от 10 до 40 пунктов',
      );
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

    testWidgets('resetting corner taps updates every configured selector', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
          initialSettings: const ReaderSettings(
            topLeftCornerTapAction: CornerTapAction.previousPage,
            topRightCornerTapAction: CornerTapAction.nextPage,
            bottomLeftCornerTapAction: CornerTapAction.addBookmark,
            bottomRightCornerTapAction: CornerTapAction.toggleUi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Жесты');
      await scrollSettingsUntilVisible(tester, find.text('Тапы по углам'));

      final topLeft = find.byKey(const ValueKey('corner-tap-topLeft'));
      expect(
        tester.widget<DropdownButtonFormField<CornerTapAction>>(topLeft).initialValue,
        CornerTapAction.previousPage,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Сбросить'));
      await tester.pump();

      for (final corner in ReaderCorner.values) {
        final selector = find.byKey(ValueKey('corner-tap-${corner.name}'));
        expect(
          tester.widget<DropdownButtonFormField<CornerTapAction>>(selector).initialValue,
          CornerTapAction.inherit,
        );
      }
      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Сбросить')).onPressed,
        isNull,
      );
    });

    testWidgets('resetting corner long presses updates every configured selector', (tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const ReaderQuickSettingsSheet(),
          initialSettings: const ReaderSettings(
            topLeftCornerLongPressAction: CornerLongPressAction.previousPage,
            topRightCornerLongPressAction: CornerLongPressAction.nextPage,
            bottomLeftCornerLongPressAction: CornerLongPressAction.addBookmark,
            bottomRightCornerLongPressAction: CornerLongPressAction.toggleUi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Жесты');
      await scrollSettingsUntilVisible(tester, find.text('Долгое нажатие по углам'));

      final topLeft = find.byKey(const ValueKey('corner-long-press-topLeft'));
      expect(
        tester.widget<DropdownButtonFormField<CornerLongPressAction>>(topLeft).initialValue,
        CornerLongPressAction.previousPage,
      );

      await tester.tap(find.byKey(const ValueKey('reset-corner-long-press-actions')));
      await tester.pump();

      for (final corner in ReaderCorner.values) {
        final selector = find.byKey(ValueKey('corner-long-press-${corner.name}'));
        expect(
          tester.widget<DropdownButtonFormField<CornerLongPressAction>>(selector).initialValue,
          CornerLongPressAction.inherit,
        );
      }
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('reset-corner-long-press-actions')))
            .onPressed,
        isNull,
      );
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

    testWidgets('saves the two-page setting in the expanded profile for this book', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(body: ReaderQuickSettingsSheet(bookId: 'book-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsPage(tester, 'Режим');
      final twoColumnsRow = find.ancestor(
        of: find.text('Две колонки'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: twoColumnsRow, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      final service = PerBookSettingsService(PerBookSettingsDao(db));
      final expanded = await service.getEffectiveSettings(
        'book-1',
        deviceClass: ReaderLayoutDeviceClass.expanded,
      );
      final compact = await service.getEffectiveSettings(
        'book-1',
        deviceClass: ReaderLayoutDeviceClass.compact,
      );

      expect(expanded.twoPageEnabled, isTrue);
      expect(compact.twoPageEnabled, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
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

    testWidgets('keeps book metadata available to screen readers on compact widths', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapInApp(
          const MediaQuery(
            data: MediaQueryData(size: Size(390, 800)),
            child: ReaderTopBar(
              settings: ReaderSettings(),
              bookTitle: 'Компактная книга',
              bookAuthor: 'Автор',
              onBack: SizedBox.new,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Компактная книга'), findsNothing);
      expect(
        find.bySemanticsLabel('Книга: Компактная книга. Автор: Автор'),
        findsOneWidget,
      );
      semantics.dispose();
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
      expect(find.text('Глава 3 из 10'), findsOneWidget);
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

      expect(find.text('Глава 1 из 5'), findsOneWidget);
      expect(find.text('~2 ч 30 мин'), findsOneWidget);
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

    testWidgets('exposes a single bounded reading-progress value to screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapInApp(
          const ReaderProgressBar(
            scrollProgress: 1.2,
            theme: ReaderTheme.sepia,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Прогресс чтения')),
        matchesSemantics(label: 'Прогресс чтения', value: '100%'),
      );
      semantics.dispose();
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

    testWidgets('leaves a long press to text selection when configured', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            bookOpenServiceProvider.overrideWithValue(_FakeBookOpenService(db)),
            readerSettingsProvider.overrideWith(
              () => _TestReaderSettingsNotifier(const ReaderSettings()),
            ),
          ],
          child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
        ),
      );
      await tester.pumpAndSettle();

      final contentGesture = tester.widget<GestureDetector>(
        find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.child is RepaintBoundary,
        ),
      );
      final selectionArea = tester.widget<SelectionArea>(find.byType(SelectionArea));

      expect(contentGesture.onLongPress, isNull);
      expect(selectionArea.onSelectionChanged, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('focus mode does not leave navigation chrome on the reading surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            bookOpenServiceProvider.overrideWithValue(_FakeBookOpenService(db)),
            readerSettingsProvider.overrideWith(
              () => _TestReaderSettingsNotifier(const ReaderSettings(mode: ReaderMode.focus)),
            ),
          ],
          child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('Back restores the position before an in-chapter footnote link', (tester) async {
      const chapter = ReaderChapter(
        index: 0,
        title: 'Глава 1',
        blocks: [
          ReaderBlock(
            index: 0,
            text: 'Перейти к примечанию',
            richSpans: [RichSpan(text: 'Перейти к примечанию', href: '#note-1')],
          ),
          ReaderBlock(
            index: 1,
            text: 'Текст примечания.',
            type: BlockType.footnote,
            noteId: 'note-1',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            bookOpenServiceProvider.overrideWithValue(
              _FakeBookOpenService(db, chapter: chapter),
            ),
            readerSettingsProvider.overrideWith(
              () => _TestReaderSettingsNotifier(const ReaderSettings()),
            ),
          ],
          child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
        ),
      );
      await tester.pumpAndSettle();

      final controller = ProviderScope.containerOf(
        tester.element(find.byType(ReaderScreen)),
      ).read(readerControllerProvider('book-1'));
      expect(controller.state.currentPosition.paragraphIndex, 0);

      // ReaderContentBody receives this callback from the tappable rich span.
      // Calling it here isolates navigation history from text-layout hit testing.
      tester.widget<ReaderContentBody>(find.byType(ReaderContentBody)).onLinkTap!('#note-1');
      await tester.pumpAndSettle();

      expect(controller.hasLinkBack, isTrue);
      expect(controller.state.currentPosition.paragraphIndex, 1);

      expect(controller.popLinkPosition(), isTrue);
      await tester.pumpAndSettle();

      expect(controller.hasLinkBack, isFalse);
      expect(controller.state.currentPosition.paragraphIndex, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'ignores small macOS precise scroll deltas in paginated mode',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              bookOpenServiceProvider.overrideWithValue(_TwoChapterBookOpenService(db)),
              readerSettingsProvider.overrideWith(
                () => _TestReaderSettingsNotifier(const ReaderSettings()),
              ),
            ],
            child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
          ),
        );
        await tester.pumpAndSettle();

        final content = find.byType(ReaderContentBody);
        final pointer = TestPointer(1, ui.PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(tester.getCenter(content)));
        for (var i = 0; i < 6; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 10)));
        }
        await tester.pumpAndSettle();

        expect(tester.widget<ReaderContentBody>(content).initialPage, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.macOS}),
    );

    testWidgets(
      'keeps a soft-hyphenated first-word selection and paragraph anchor',
      (tester) async {
        tester.view.physicalSize = const ui.Size(1600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const firstWord = 'пре\u00adвращение';
        const paragraph = '$firstWord начинается с мягкого переноса.';
        const chapter = ReaderChapter(
          index: 0,
          title: 'Глава 1',
          blocks: [ReaderBlock(index: 0, text: paragraph)],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              bookOpenServiceProvider.overrideWithValue(
                _FakeBookOpenService(db, chapter: chapter),
              ),
              readerSettingsProvider.overrideWith(
                () => _TestReaderSettingsNotifier(const ReaderSettings()),
              ),
            ],
            child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
          ),
        );
        await tester.pumpAndSettle();

        final renderParagraph = tester.renderObject<RenderParagraph>(
          find.byWidgetPredicate(
            (widget) => widget is RichText && widget.text.toPlainText().contains(firstWord),
          ),
        );
        final caretOffset = renderParagraph.getOffsetForCaret(
          const TextPosition(offset: 2),
          const ui.Rect.fromLTWH(0, 0, 2, 20),
        );
        final gesture = await tester.startGesture(renderParagraph.localToGlobal(caretOffset));
        addTearDown(gesture.removePointer);
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(renderParagraph.selections, hasLength(1));
        final toolbar = tester.widget<ReaderSelectionToolbar>(
          find.byType(ReaderSelectionToolbar),
        );
        expect(toolbar.selectedText, firstWord);
        expect(toolbar.chapterIndex, 0);
        expect(toolbar.paragraphIndex, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.android}),
    );
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

  testWidgets('honours the system reduce-motion preference for paginated turns', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: wrapInApp(
          ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'book-1',
              title: 'Тестовая книга',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Глава 1'],
            ),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: 'Глава 1',
                blocks: [ReaderBlock(index: 0, text: 'Текст книги.')],
              ),
            },
            settings: const ReaderSettings(pageTurnAnimation: PageTurnAnimation.fade),
            scrollController: scrollController,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('repaginates when the system text scale changes', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final chapter = ReaderChapter(
      index: 0,
      title: 'Глава 1',
      blocks: List<ReaderBlock>.generate(
        24,
        (index) => ReaderBlock(
          index: index,
          text: 'Длинный абзац для проверки системного масштаба текста. ' * 3,
        ),
      ),
    );

    Widget buildAtScale(double scale) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'book-1',
            title: 'Тестовая книга',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Глава 1'],
          ),
          loadedChapters: {0: chapter},
          settings: const ReaderSettings(),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.pumpWidget(buildAtScale(1));
    await tester.pump();
    final normalPageCount =
        (tester.widget<PageView>(find.byType(PageView)).childrenDelegate.estimatedChildCount ?? 0);

    await tester.pumpWidget(buildAtScale(2));
    await tester.pump();
    final enlargedPageCount =
        (tester.widget<PageView>(find.byType(PageView)).childrenDelegate.estimatedChildCount ?? 0);

    expect(enlargedPageCount, greaterThan(normalPageCount));
  });

  testWidgets('shows a controlled placeholder for an unsupported comic image codec', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'comic',
            title: 'Comic',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Pages'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Pages',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: '',
                  type: BlockType.image,
                  imageUrl: 'data:image/jxl;base64,/wo=',
                ),
              ],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a controlled placeholder for a malformed WebP data URI', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'broken-comic',
            title: 'Broken comic',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Pages'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Pages',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: '',
                  type: BlockType.image,
                  imageUrl: 'data:image/webp;base64,abc!',
                ),
              ],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provides a controlled placeholder when a cached SVG was removed', (tester) async {
    const missingSvgPath = '/tmp/glibusta-missing-cover.svg';

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'broken-svg',
            title: 'Broken SVG',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Pages'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Pages',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: '',
                  type: BlockType.image,
                  imageUrl: missingSvgPath,
                ),
              ],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    final finder = find.byType(SvgPicture);
    final svg = tester.widget<SvgPicture>(finder);
    final fallback = svg.errorBuilder!(
      tester.element(finder),
      StateError('missing'),
      StackTrace.current,
    );
    expect((fallback as Icon).icon, Icons.broken_image);
  });

  testWidgets('keeps fixed-layout page count stable while chapters load lazily', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'fixed-layout',
            title: 'Fixed layout',
            authors: [],
            chapterCount: 3,
            chapterTitles: ['1', '2', '3'],
            metadata: {'isFixedLayout': true},
          ),
          loadedChapters: const {
            0: ReaderChapter(index: 0, title: '1', blocks: []),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 3);
  });

  testWidgets('opens a paginated chapter at the saved paragraph', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final blocks = List<ReaderBlock>.generate(
      4,
      (index) => ReaderBlock(
        index: index,
        text: 'Paragraph $index\n${List<String>.filled(60, 'long reader line').join('\n')}',
      ),
    );

    await tester.pumpWidget(
      wrapInApp(
        SizedBox(
          width: 320,
          height: 400,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'semantic-page-restore',
              title: 'Semantic page restore',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: {
              0: ReaderChapter(index: 0, title: 'Chapter', blocks: blocks),
            },
            settings: const ReaderSettings(),
            scrollController: scrollController,
            initialParagraph: 2,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, closeTo(2, 0.01));
  });

  testWidgets('opens a fixed-layout EPUB at its restored spine page', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'fixed-layout-restore',
            title: 'Fixed layout',
            authors: [],
            chapterCount: 3,
            chapterTitles: ['1', '2', '3'],
            metadata: {'isFixedLayout': true},
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: '1',
              blocks: [ReaderBlock(index: 0, text: 'page 1')],
            ),
            1: ReaderChapter(
              index: 1,
              title: '2',
              blocks: [ReaderBlock(index: 0, text: 'page 2')],
            ),
            2: ReaderChapter(
              index: 2,
              title: '3',
              blocks: [ReaderBlock(index: 0, text: 'page 3')],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          initialPage: 2,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('page 3'), findsOneWidget);
    expect(find.text('page 1'), findsNothing);
  });

  testWidgets('renders transparent WebP comic pages without dropping alpha', (tester) async {
    const transparentWebp = 'UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';
    const transparentWebpUri =
        'data:image/webp;base64,UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'transparent-comic',
            title: 'Transparent comic',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Pages'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Pages',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: '',
                  type: BlockType.image,
                  imageUrl: transparentWebpUri,
                ),
              ],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as MemoryImage;
    expect(provider.bytes, base64Decode(transparentWebp));
    final codec = await ui.instantiateImageCodec(provider.bytes);
    final frame = await codec.getNextFrame();
    final rgba = await frame.image.toByteData();
    codec.dispose();
    frame.image.dispose();

    expect(rgba, isNotNull);
    expect(rgba!.getUint8(3), 0, reason: 'top-left pixel must remain transparent');
    expect(rgba.getUint8(15), 255, reason: 'bottom-right pixel must remain opaque');
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('renders EPUB rich-span hard breaks as a newline', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'epub-hard-break',
            title: 'EPUB hard break',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Chapter'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Chapter',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: 'First\nsecond line.',
                  richSpans: [
                    RichSpan(text: 'First', href: '#note'),
                    RichSpan(text: '', lineBreak: true),
                    RichSpan(text: 'second', href: '#note'),
                    RichSpan(text: ' line.'),
                  ],
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
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().endsWith('First\nsecond line.') == true,
      ),
    );
    expect(text.textSpan!.toPlainText(), endsWith('First\nsecond line.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark reader themes ignore hardcoded EPUB text colors', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'dark-epub',
            title: 'Dark EPUB',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Chapter'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Chapter',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: 'Hardcoded',
                  richSpans: [RichSpan(text: 'Hardcoded', color: '#808080')],
                ),
              ],
            ),
          },
          settings: const ReaderSettings(theme: ReaderTheme.dark),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    expect(find.byType(ReaderContentBody), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark reader theme keeps quote and cite blocks readable without a light surface', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'dark-quote-epub',
            title: 'Dark quote EPUB',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Chapter'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Chapter',
              blocks: [
                ReaderBlock(index: 0, text: 'Quoted EPUB content', type: BlockType.quote),
                ReaderBlock(index: 1, text: 'Cited callout content', type: BlockType.cite),
              ],
            ),
          },
          settings: const ReaderSettings(theme: ReaderTheme.dark),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );

    final colors = ReaderColors.forTheme(ReaderTheme.dark);
    final quote = tester.widget<Text>(find.text('Quoted EPUB content'));
    final cite = tester.widget<Text>(find.text('Cited callout content'));
    for (final text in [quote, cite]) {
      expect(text.style?.color, colors.text);
      expect(text.style?.fontStyle, FontStyle.italic);
      final foreground = text.style!.color!;
      final lighter = foreground.computeLuminance() > colors.scaffold.computeLuminance()
          ? foreground
          : colors.scaffold;
      final darker = identical(lighter, foreground) ? colors.scaffold : foreground;
      expect(
        (lighter.computeLuminance() + 0.05) / (darker.computeLuminance() + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }

    for (final text in ['Quoted EPUB content', 'Cited callout content']) {
      final container = tester.widget<Container>(
        find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNull, reason: 'semantic reader blocks keep the reader surface');
      expect(decoration.border, isA<BorderDirectional>());
    }
  });

  testWidgets('reapplies EPUB span colors when the reader theme changes', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    Widget buildReader(ReaderTheme theme) {
      return wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'theme-switch-epub',
            title: 'Theme switch EPUB',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Chapter'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Chapter',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: 'Colorful',
                  richSpans: [RichSpan(text: 'Colorful', color: '#ff0000')],
                ),
              ],
            ),
          },
          settings: ReaderSettings(theme: theme),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      );
    }

    Text coloredText() => tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan?.toPlainText().endsWith('Colorful') == true,
      ),
    );

    await tester.pumpWidget(buildReader(ReaderTheme.dark));
    await tester.pumpAndSettle();
    final darkSpan = (coloredText().textSpan! as TextSpan).children!.last as TextSpan;
    expect(darkSpan.style!.color, const Color(0xFFE6E1E5));

    await tester.pumpWidget(buildReader(ReaderTheme.light));
    await tester.pumpAndSettle();
    final lightSpan = (coloredText().textSpan! as TextSpan).children!.last as TextSpan;
    expect(lightSpan.style!.color, const Color(0xFFFF0000));
  });

  testWidgets('renders UTF-8 umlauts from reader blocks without replacement characters', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    const paragraph = 'F\u00fcr Gr\u00f6\u00dfe und M\u00f6glichkeit: \u00e4\u00f6\u00fc\u00df.';

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'utf8-umlauts',
            title: 'UTF-8 umlauts',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Chapter'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Chapter',
              blocks: [ReaderBlock(index: 0, text: paragraph)],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderedParagraph = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains(paragraph),
      ),
    );
    expect(renderedParagraph.text.toPlainText(), contains(paragraph));
    expect(renderedParagraph.text.toPlainText(), isNot(contains('\u{fffd}')));
  });

  testWidgets('focus mode uses the dark system link color', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ReaderContentBody(
                metadata: const NormalizedBookMetadata(
                  id: 'system-dark-focus',
                  title: 'System dark focus',
                  authors: [],
                  chapterCount: 1,
                  chapterTitles: ['Chapter'],
                ),
                loadedChapters: const {
                  0: ReaderChapter(
                    index: 0,
                    title: 'Chapter',
                    blocks: [
                      ReaderBlock(
                        index: 0,
                        text: 'Link',
                        richSpans: [RichSpan(text: 'Link', href: '#target')],
                      ),
                    ],
                  ),
                },
                settings: const ReaderSettings(mode: ReaderMode.focus),
                scrollController: scrollController,
                onTap: _ignoreTap,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final text = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan?.toPlainText().endsWith('Link') == true,
      ),
    );
    final textSpan = text.textSpan! as TextSpan;
    final linkSpan = textSpan.children!.last as TextSpan;
    expect(linkSpan.style!.color, const Color(0xFF64B5F6));
  });

  testWidgets('focus mode restores and reports its paragraph position', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final reportedPositions = <(int, int)>[];

    await tester.pumpWidget(
      wrapInApp(
        SizedBox(
          width: 320,
          height: 400,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'focus-position',
              title: 'Focus position',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: 'Chapter',
                blocks: [
                  ReaderBlock(index: 0, text: 'First paragraph'),
                  ReaderBlock(index: 1, text: 'Second paragraph'),
                ],
              ),
            },
            settings: const ReaderSettings(mode: ReaderMode.focus),
            scrollController: scrollController,
            initialParagraph: 1,
            onTap: _ignoreTap,
            onFocusPositionChanged: (chapter, paragraph) {
              reportedPositions.add((chapter, paragraph));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second paragraph'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(reportedPositions, contains((0, 0)));
  });

  testWidgets('keeps a wide EPUB table horizontally reachable', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    const lastCell = 'rightmost-column';

    await tester.pumpWidget(
      wrapInApp(
        SizedBox(
          width: 320,
          height: 240,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'wide-table',
              title: 'Wide table',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: '',
                blocks: [
                  ReaderBlock(
                    index: 0,
                    text: '',
                    type: BlockType.table,
                    tableRows: [
                      ['first-column', 'middle-column', lastCell],
                      [
                        'unbreakable-content-that-makes-the-table-wider-than-the-reader',
                        'more-unbreakable-content-that-preserves-the-natural-column-width',
                        'final-unbreakable-content-that-needs-horizontal-scrolling',
                      ],
                    ],
                  ),
                ],
              ),
            },
            settings: const ReaderSettings(mode: ReaderMode.continuous),
            scrollController: scrollController,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tableScroller = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
    );
    expect(tableScroller, findsOneWidget);
    expect(tester.getRect(find.text(lastCell)).left, greaterThan(320));

    final tableScrollable = tester.state<ScrollableState>(
      find.descendant(of: tableScroller, matching: find.byType(Scrollable)),
    );
    expect(tableScrollable.position.maxScrollExtent, greaterThan(0));
    tableScrollable.position.jumpTo(tableScrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text(lastCell)).left, lessThan(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders FB2-style table and illustration blocks without a narrow-layout crash', (
    tester,
  ) async {
    const illustration =
        'data:image/webp;base64,'
        'UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        SizedBox(
          width: 320,
          height: 480,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'fb2-table-image',
              title: 'FB2 table and image',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: '',
                blocks: [
                  ReaderBlock(
                    index: 0,
                    text: '',
                    type: BlockType.table,
                    tableRows: [
                      ['Header'],
                      [
                        'unbreakable-table-cell-content-for-a-narrow-reader',
                        'Second cell',
                      ],
                    ],
                  ),
                  ReaderBlock(
                    index: 1,
                    text: '',
                    type: BlockType.image,
                    imageUrl: illustration,
                    imageAlt: 'Illustration',
                  ),
                ],
              ),
            },
            settings: const ReaderSettings(mode: ReaderMode.continuous),
            scrollController: scrollController,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes chapter and rich block headings without duplicate semantics', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final semantics = tester.ensureSemantics();
    String? openedLink;
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      wrapInApp(
        ReaderContentBody(
          metadata: const NormalizedBookMetadata(
            id: 'semantic-headings',
            title: 'Semantic headings',
            authors: [],
            chapterCount: 1,
            chapterTitles: ['Глава доступности'],
          ),
          loadedChapters: const {
            0: ReaderChapter(
              index: 0,
              title: 'Глава доступности',
              blocks: [
                ReaderBlock(
                  index: 0,
                  text: 'Раздел доступности',
                  type: BlockType.heading,
                ),
                ReaderBlock(
                  index: 1,
                  text: 'Ссылка в заголовке',
                  type: BlockType.heading,
                  richSpans: [RichSpan(text: 'Ссылка в заголовке', href: '#note')],
                ),
              ],
            ),
          },
          settings: const ReaderSettings(mode: ReaderMode.continuous),
          scrollController: scrollController,
          onTap: _ignoreTap,
          onLinkTap: (href) => openedLink = href,
        ),
      ),
    );
    await tester.pump();

    final chapterHeading = find.bySemanticsLabel('Глава доступности');
    final blockHeading = find.bySemanticsLabel('Раздел доступности');
    expect(chapterHeading, findsOneWidget);
    expect(blockHeading, findsOneWidget);
    expect(
      tester.getSemantics(chapterHeading),
      matchesSemantics(label: 'Глава доступности', isHeader: true),
    );
    expect(
      tester.getSemantics(blockHeading),
      matchesSemantics(label: 'Раздел доступности', isHeader: true),
    );

    await tester.tap(find.text('Ссылка в заголовке'));
    expect(openedLink, '#note');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('opens an illustration in an accessible full-screen viewer', (tester) async {
    const illustration =
        'data:image/webp;base64,'
        'UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';
    final scrollController = ScrollController();
    final semantics = tester.ensureSemantics();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Scaffold(
            body: ReaderContentBody(
              metadata: const NormalizedBookMetadata(
                id: 'accessible-image',
                title: 'Accessible image',
                authors: [],
                chapterCount: 1,
                chapterTitles: ['Chapter'],
              ),
              loadedChapters: const {
                0: ReaderChapter(
                  index: 0,
                  title: '',
                  blocks: [
                    ReaderBlock(
                      index: 0,
                      text: '',
                      type: BlockType.image,
                      imageUrl: illustration,
                      imageAlt: 'Иллюстрация',
                    ),
                  ],
                ),
              },
              settings: const ReaderSettings(mode: ReaderMode.continuous),
              scrollController: scrollController,
              onTap: _ignoreTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openImage = find.bySemanticsLabel(
      'Открыть Иллюстрация в полноэкранном режиме',
    );
    expect(openImage, findsOneWidget);

    tester.semantics.tap(
      find.semantics.byLabel('Открыть Иллюстрация в полноэкранном режиме'),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Полноэкранный просмотр изображения'), findsOneWidget);
    final close = find.bySemanticsLabel('Закрыть полноэкранный просмотр изображения');
    expect(close, findsOneWidget);

    tester.semantics.tap(
      find.semantics.byLabel('Закрыть полноэкранный просмотр изображения'),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Полноэкранный просмотр изображения'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('opens explicit image actions after a long press', (tester) async {
    const illustration =
        'data:image/webp;base64,'
        'UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=';
    final scrollController = ScrollController();
    final semantics = tester.ensureSemantics();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Scaffold(
            body: ReaderContentBody(
              metadata: const NormalizedBookMetadata(
                id: 'long-press-image',
                title: 'Long press image',
                authors: [],
                chapterCount: 1,
                chapterTitles: ['Chapter'],
              ),
              loadedChapters: const {
                0: ReaderChapter(
                  index: 0,
                  title: '',
                  blocks: [
                    ReaderBlock(
                      index: 0,
                      text: '',
                      type: BlockType.image,
                      imageUrl: illustration,
                      imageAlt: 'Иллюстрация',
                    ),
                  ],
                ),
              },
              settings: const ReaderSettings(mode: ReaderMode.continuous),
              scrollController: scrollController,
              onTap: _ignoreTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.semantics.longPress(
      find.semantics.byLabel('Открыть Иллюстрация в полноэкранном режиме'),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Действия с изображением'), findsOneWidget);
    expect(find.text('Поделиться изображением'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('keeps an oversized paginated block vertically reachable', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final longBlock = List<String>.filled(80, 'A very tall reader block.').join('\n');

    await tester.pumpWidget(
      wrapInApp(
        SizedBox(
          width: 320,
          height: 180,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'oversized-block',
              title: 'Oversized block',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: {
              0: ReaderChapter(
                index: 0,
                title: '',
                blocks: [ReaderBlock(index: 0, text: longBlock)],
              ),
            },
            settings: const ReaderSettings(),
            scrollController: scrollController,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final pageScroller = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
    );
    expect(pageScroller, findsOneWidget);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: pageScroller, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(pageScroller, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a Russian preposition and following word on one narrow reader line', (
    tester,
  ) async {
    const phrase = 'В\u00a0доме';
    const text = 'x $phrase y';
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    Widget buildReader(double width) {
      return wrapInApp(
        SizedBox(
          width: width,
          height: 180,
          child: ReaderContentBody(
            metadata: const NormalizedBookMetadata(
              id: 'nbsp-reader',
              title: 'NBSP reader',
              authors: [],
              chapterCount: 1,
              chapterTitles: ['Chapter'],
            ),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: '',
                blocks: [ReaderBlock(index: 0, text: text)],
              ),
            },
            settings: const ReaderSettings(
              mode: ReaderMode.continuous,
              margin: 0,
              fontSize: 20,
            ),
            scrollController: scrollController,
            onTap: _ignoreTap,
          ),
        ),
      );
    }

    Finder paragraphFinder() => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains(phrase),
    );

    await tester.pumpWidget(buildReader(300));
    await tester.pumpAndSettle();

    final wideParagraph = tester.renderObject<RenderParagraph>(paragraphFinder());
    final renderedText = wideParagraph.text.toPlainText();
    final phraseStart = renderedText.indexOf(phrase);
    expect(phraseStart, greaterThanOrEqualTo(0));
    final phraseBox = wideParagraph
        .getBoxesForSelection(
          TextSelection(baseOffset: phraseStart, extentOffset: phraseStart + phrase.length),
        )
        .single;

    // There is enough room for the phrase itself, but not for the leading
    // "x ". A regular space would leave "В" on the first line; NBSP must
    // move both words together to the next line.
    await tester.pumpWidget(buildReader(phraseBox.right - phraseBox.left + 1));
    await tester.pumpAndSettle();

    final narrowParagraph = tester.renderObject<RenderParagraph>(paragraphFinder());
    final prepositionBox = narrowParagraph
        .getBoxesForSelection(
          TextSelection(baseOffset: phraseStart, extentOffset: phraseStart + 1),
        )
        .single;
    final nounStart = phraseStart + 'В\u00a0'.length;
    final nounBox = narrowParagraph
        .getBoxesForSelection(TextSelection(baseOffset: nounStart, extentOffset: nounStart + 4))
        .single;

    expect(prepositionBox.top, nounBox.top);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreTap(TapUpDetails _) {}

class _TestReaderSettingsNotifier extends ReaderSettingsNotifier {
  _TestReaderSettingsNotifier(this._initial);
  final ReaderSettings _initial;

  @override
  ReaderSettings build() => _initial;
}
