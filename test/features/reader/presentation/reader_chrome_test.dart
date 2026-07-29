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
}
