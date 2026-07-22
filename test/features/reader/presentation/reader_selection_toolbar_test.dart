import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_selection_toolbar.dart';

void main() {
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
}
