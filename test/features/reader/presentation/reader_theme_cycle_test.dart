import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme cycle button shown when callback provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: ReaderSettings(theme: ReaderTheme.dark),
            bookTitle: 'Test',
            onBack: _noOp,
            onCycleTheme: _noOp,
          ),
        ),
      ),
    );
    // dark theme → dark_mode_outlined icon
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
  });

  testWidgets('theme cycle button hidden when callback null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: ReaderSettings(theme: ReaderTheme.dark),
            bookTitle: 'Test',
            onBack: _noOp,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
  });

  testWidgets('tapping theme cycle calls callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: const ReaderSettings(theme: ReaderTheme.dark),
            bookTitle: 'Test',
            onBack: () {},
            onCycleTheme: () => pressed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    expect(pressed, isTrue);
  });

  testWidgets('sepia theme shows correct icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderTopBar(
            settings: ReaderSettings(theme: ReaderTheme.sepia),
            bookTitle: 'Test',
            onBack: _noOp,
            onCycleTheme: _noOp,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
  });

  group('theme cycle order', () {
    const cycle = [
      ReaderTheme.light,
      ReaderTheme.sepia,
      ReaderTheme.dark,
      ReaderTheme.oled,
      ReaderTheme.bedtime,
      ReaderTheme.paper,
    ];

    test('next theme after light is sepia', () {
      final idx = cycle.indexOf(ReaderTheme.light);
      expect(cycle[(idx + 1) % cycle.length], ReaderTheme.sepia);
    });

    test('next theme after paper wraps to light', () {
      final idx = cycle.indexOf(ReaderTheme.paper);
      expect(cycle[(idx + 1) % cycle.length], ReaderTheme.light);
    });
  });
}

void _noOp() {}
