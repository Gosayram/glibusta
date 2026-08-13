import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glibusta/features/reader/presentation/reader_screen.dart';

void main() {
  testWidgets('opens an external reader link only after explicit confirmation', (tester) async {
    var opened = false;
    final uri = Uri.parse('https://example.com/book');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              showExternalLinkConfirmation(
                context,
                uri,
                openExternalLink: (_) async {
                  opened = true;
                  return true;
                },
              ),
            ),
            child: const Text('Follow link'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Follow link'));
    await tester.pumpAndSettle();

    expect(find.text('Внешняя ссылка'), findsOneWidget);
    expect(opened, isFalse);

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}
