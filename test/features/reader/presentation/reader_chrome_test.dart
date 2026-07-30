import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';

void main() {
  testWidgets('chrome guide explains central tap and keeps a single semantic node', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReaderChromeVisibilityGuide()),
      ),
    );

    expect(find.byKey(const Key('reader_chrome_visibility_guide')), findsOneWidget);
    expect(find.text('Панели чтения'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('reader_chrome_visibility_guide'))),
      matchesSemantics(
        label:
            'Панели чтения. Центральное касание показывает или скрывает верхнюю и '
            'нижнюю панель. Верхняя панель содержит содержание, поиск и настройки. '
            'Нижняя показывает прогресс и режим чтения. Время автоскрытия настраивается '
            'ниже. Строки информации на странице настраиваются в настройках приложения.',
      ),
    );
    semantics.dispose();
  });

  testWidgets('shows link forward only while link history can advance', (tester) async {
    var forwardCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: const ReaderSettings(),
            bookTitle: 'Book',
            onBack: () {},
            hasLinkForward: true,
            onLinkForward: () => forwardCalls++,
          ),
        ),
      ),
    );

    final forward = find.byTooltip('Вперёд по ссылке');
    expect(forward, findsOneWidget);
    await tester.tap(forward);
    expect(forwardCalls, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: ReaderSettings(),
            bookTitle: 'Book',
            onBack: _noOp,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Вперёд по ссылке'), findsNothing);
  });

  testWidgets('mode switcher supports keyboard focus and activation', (tester) async {
    ReaderMode? selectedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 1,
            scrollProgress: 0,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onModeChanged: (mode) => selectedMode = mode,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(selectedMode, ReaderMode.continuous);
  });

  testWidgets('mode switcher does not overflow at 200% system text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: ReaderBottomBar(
              settings: const ReaderSettings(),
              currentChapterIndex: 0,
              totalChapters: 1,
              scrollProgress: 0,
              estimatedMinutesLeft: 0,
              chapterTitle: '',
              onModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the actual chapter instead of inferring one from scroll progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: ReaderSettings(bottomBarContent: BottomBarContent.chapter),
            currentChapterIndex: 1,
            totalChapters: 10,
            scrollProgress: 0.9,
            estimatedMinutesLeft: 10,
            chapterTitle: 'Настоящая глава',
          ),
        ),
      ),
    );

    expect(find.text('Глава 2 из 10'), findsOneWidget);
    expect(find.text('Глава 9 из 10'), findsNothing);
    expect(
      tester.getSemantics(find.text('Глава 2 из 10')),
      matchesSemantics(label: 'Позиция чтения: Глава 2 из 10'),
    );
    expect(
      tester.getSemantics(find.text('Настоящая глава')),
      matchesSemantics(
        label: 'Текущая глава: Настоящая глава',
        isHeader: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('exposes checkpoint navigation as labelled keyboard actions', (tester) async {
    var movedBack = 0;
    var movedForward = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 1,
            totalChapters: 3,
            scrollProgress: 0.5,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) {},
            onCheckpointBack: () => movedBack++,
            onCheckpointForward: () => movedForward++,
          ),
        ),
      ),
    );

    final previous = find.bySemanticsLabel('Перейти к предыдущей закладке');
    final next = find.bySemanticsLabel('Перейти к следующей закладке');
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(movedBack, 1);
    await tester.tap(next);
    expect(movedForward, 1);

    semantics.dispose();
  });

  testWidgets('jumps to a valid percentage through an accessible dialog', (tester) async {
    double? jumpedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 3,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (value) => jumpedTo = value,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    expect(find.text('Перейти к проценту'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '25');

    await tester.enterText(find.byType(TextField), '37.5');
    await tester.tap(find.text('Перейти'));
    await tester.pumpAndSettle();

    expect(jumpedTo, 0.375);
  });

  testWidgets('does not jump when entered percentage is out of bounds', (tester) async {
    var jumps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 1,
            scrollProgress: 0,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) => jumps++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '101');
    await tester.tap(find.text('Перейти'));
    await tester.pump();

    expect(find.text('Введите число от 0 до 100'), findsOneWidget);
    expect(jumps, 0);
  });

  testWidgets('jumps to boundary value 0', (tester) async {
    double? jumpedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 3,
            scrollProgress: 0.5,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (value) => jumpedTo = value,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Перейти'));
    await tester.pumpAndSettle();

    expect(jumpedTo, 0.0);
  });

  testWidgets('jumps to boundary value 100', (tester) async {
    double? jumpedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 3,
            scrollProgress: 0.5,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (value) => jumpedTo = value,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Перейти'));
    await tester.pumpAndSettle();

    expect(jumpedTo, 1.0);
  });

  testWidgets('does not jump on non-numeric input', (tester) async {
    var jumps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 1,
            scrollProgress: 0,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) => jumps++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Перейти'));
    await tester.pump();

    expect(find.text('Введите число от 0 до 100'), findsOneWidget);
    expect(jumps, 0);
  });

  testWidgets('cancel dismisses dialog without jumping', (tester) async {
    var jumps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 1,
            scrollProgress: 0.5,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) => jumps++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    expect(find.text('Отмена'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(jumps, 0);
  });

  testWidgets('dialog shows current percentage as initial value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 3,
            scrollProgress: 0.73,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '73',
    );
  });

  testWidgets('negative value is rejected', (tester) async {
    var jumps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 0,
            totalChapters: 1,
            scrollProgress: 0,
            estimatedMinutesLeft: 0,
            chapterTitle: '',
            onJumpToProgress: (_) => jumps++,
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Перейти к проценту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-5');
    await tester.tap(find.text('Перейти'));
    await tester.pump();

    expect(find.text('Введите число от 0 до 100'), findsOneWidget);
    expect(jumps, 0);
  });
}

void _noOp() {}
