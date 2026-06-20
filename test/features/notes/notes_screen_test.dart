import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/notes/data/notes_providers.dart';
import 'package:glibusta/features/notes/presentation/notes_screen.dart';

void main() {
  Widget buildTestWidget({String bookId = 'test-book-id'}) {
    return ProviderScope(
      overrides: [
        notesStreamProvider(bookId).overrideWithValue(
          const AsyncData([]),
        ),
      ],
      child: MaterialApp(
        home: NotesScreen(bookId: bookId),
      ),
    );
  }

  group('NotesScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Заметки'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Нет заметок'), findsOneWidget);
      expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
    });

    testWidgets('shows button to open library', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Открыть библиотеку'), findsOneWidget);
    });
  });
}
