import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_selection_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the selected text before an online dictionary request', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const selectedText = 'Слово для проверки';

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReaderSelectionToolbar(
              bookId: 'book-1',
              chapterIndex: 0,
              paragraphIndex: 0,
              selectedText: selectedText,
              onDismiss: _noop,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Словарь'));
    await tester.tap(find.text('Словарь'));
    await tester.pumpAndSettle();

    expect(find.text('Онлайн-словарь'), findsOneWidget);
    expect(find.textContaining('en.wiktionary.org'), findsOneWidget);
    expect(find.textContaining('«$selectedText»'), findsOneWidget);
  });
}

void _noop() {}
