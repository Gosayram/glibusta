import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glibusta/shared/widgets/delete_book_dialog.dart';

void main() {
  group('DeleteBookDialog', () {
    testWidgets('shows book title and checkbox unchecked by default', (tester) async {
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
      expect(find.text('Удалить файл с диска'), findsOneWidget);

      final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, isFalse);
    });

    testWidgets('checkbox toggles on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DeleteBookDialog.show(context, bookTitle: 'Test'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, isTrue);
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

    testWidgets('delete without checkbox returns deleteFile=false', (tester) async {
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

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.deleteFile, isFalse);
    });

    testWidgets('delete with checkbox returns deleteFile=true', (tester) async {
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

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.deleteFile, isTrue);
    });
  });
}
