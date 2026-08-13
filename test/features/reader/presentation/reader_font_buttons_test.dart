import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settings = ReaderSettings();

  testWidgets('font decrease button is shown when callback is provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: settings,
            bookTitle: 'Test',
            onBack: () {},
            onFontDecrease: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.text_decrease), findsOneWidget);
  });

  testWidgets('font increase button is shown when callback is provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: settings,
            bookTitle: 'Test',
            onBack: () {},
            onFontIncrease: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.text_increase), findsOneWidget);
  });

  testWidgets('font buttons hidden when callbacks are null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: settings,
            bookTitle: 'Test',
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.text_decrease), findsNothing);
    expect(find.byIcon(Icons.text_increase), findsNothing);
  });

  testWidgets('tapping font increase calls callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: settings,
            bookTitle: 'Test',
            onBack: () {},
            onFontIncrease: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.text_increase));
    expect(pressed, isTrue);
  });

  testWidgets('tapping font decrease calls callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: settings,
            bookTitle: 'Test',
            onBack: () {},
            onFontDecrease: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.text_decrease));
    expect(pressed, isTrue);
  });
}
