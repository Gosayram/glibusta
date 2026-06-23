import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glibusta/shared/widgets/delete_book_dialog.dart';

void main() {
  group('DeleteBookDialog', () {
    testWidgets('shows book title and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DeleteBookDialog.show(context, bookTitle: 'Test Book'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Удалить книгу?'), findsOneWidget);
      expect(find.text('«Test Book»'), findsOneWidget);
      expect(find.text('Из списка'), findsOneWidget);
      expect(find.text('С файлом'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      DeleteBookResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DeleteBookDialog.show(context, bookTitle: 'Test');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Из списка returns deleteFile=false', (tester) async {
      DeleteBookResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DeleteBookDialog.show(context, bookTitle: 'Test');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Из списка'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.deleteFile, isFalse);
    });

    testWidgets('С файлом returns deleteFile=true', (tester) async {
      DeleteBookResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await DeleteBookDialog.show(context, bookTitle: 'Test');
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('С файлом'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.deleteFile, isTrue);
    });
  });
}
