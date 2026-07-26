import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';

void main() {
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
}
