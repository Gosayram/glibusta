import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:glibusta/core/services/tts_controller.dart';
import 'package:glibusta/features/reader/presentation/reader_selection_toolbar.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  testWidgets('keeps every selection action reachable on a narrow reader', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: 'Selected text',
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the parent-updated selection for in-book search', (tester) async {
    String? searchedText;
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildToolbar(String selectedText) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: selectedText,
              onDismiss: () {},
              onSearchInBook: (text) => searchedText = text,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildToolbar('stale selection'));
    await tester.pumpWidget(buildToolbar('current selection'));

    await tester.tap(find.text('В книге'));

    expect(searchedText, 'current selection');
  });

  testWidgets('keeps an accessible stop action for the active selection narration', (
    tester,
  ) async {
    final tts = _MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async {});
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async {});
    when(() => tts.speak(any())).thenAnswer((_) async {});
    when(() => tts.stop()).thenAnswer((_) async {});
    final controller = TtsController.forTesting(() => tts);
    var dismissals = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: 'Selected text',
              onDismiss: () => dismissals++,
              ttsController: controller,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Озвучить'));
    await tester.tap(find.text('Озвучить'));
    await tester.pump();

    verify(() => tts.speak('Selected text')).called(1);
    expect(find.text('Остановить'), findsOneWidget);
    expect(dismissals, 0);

    await tester.ensureVisible(find.text('Остановить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Остановить'));
    await tester.pump();

    verify(() => tts.stop()).called(1);
    expect(find.text('Озвучить'), findsOneWidget);
  });

  testWidgets('starts and cancels a sleep timer from the selection toolbar', (tester) async {
    final tts = _MockFlutterTts();
    final controller = TtsController.forTesting(() => tts);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: 'Selected text',
              onDismiss: () {},
              ttsController: controller,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Таймер сна'));
    await tester.tap(find.text('Таймер сна'));
    await tester.pumpAndSettle();
    expect(find.text('Остановит озвучивание через выбранное время'), findsOneWidget);

    await tester.tap(find.text('30 минут'));
    await tester.pumpAndSettle();
    expect(controller.sleepTimerDuration, const Duration(minutes: 30));
    expect(find.text('Таймер: 30 мин'), findsOneWidget);

    await tester.ensureVisible(find.text('Таймер: 30 мин'));
    await tester.tap(find.text('Таймер: 30 мин'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отключить таймер сна'));
    await tester.pumpAndSettle();

    expect(controller.hasSleepTimer, isFalse);
    expect(find.text('Таймер сна'), findsOneWidget);
  });
}
