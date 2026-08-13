import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prev chapter button shown when callback provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: ReaderSettings(),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 30,
            chapterTitle: 'Test Chapter',
            onPrevChapter: _noOp,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
  });

  testWidgets('next chapter button shown when callback provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: ReaderSettings(),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 30,
            chapterTitle: 'Test Chapter',
            onNextChapter: _noOp,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });

  testWidgets('chapter nav buttons hidden when callbacks null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: ReaderSettings(),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 30,
            chapterTitle: 'Test Chapter',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.skip_previous), findsNothing);
    expect(find.byIcon(Icons.skip_next), findsNothing);
  });

  testWidgets('tapping prev chapter calls callback', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 30,
            chapterTitle: 'Test Chapter',
            onPrevChapter: () => pressed++,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.skip_previous));
    expect(pressed, 1);
  });

  testWidgets('tapping next chapter calls callback', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            settings: const ReaderSettings(),
            currentChapterIndex: 2,
            totalChapters: 10,
            scrollProgress: 0.25,
            estimatedMinutesLeft: 30,
            chapterTitle: 'Test Chapter',
            onNextChapter: () => pressed++,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.skip_next));
    expect(pressed, 1);
  });
}

void _noOp() {}
