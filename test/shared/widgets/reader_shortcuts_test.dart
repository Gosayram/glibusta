import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/widgets/reader_shortcuts.dart';

void main() {
  testWidgets('supports primary reader shortcuts on control-based keyboards', (tester) async {
    var searches = 0;
    var bookmarks = 0;
    var settings = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderShortcuts(
            onSearch: () => searches++,
            onBookmarks: () => bookmarks++,
            onSettings: () => settings++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(searches, 1);
    expect(bookmarks, 1);
    expect(settings, 1);
  });

  testWidgets('treats plus as an increase-font shortcut', (tester) async {
    var increased = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderShortcuts(
            onIncreaseFontSize: () => increased++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(increased, 1);
  });
}
