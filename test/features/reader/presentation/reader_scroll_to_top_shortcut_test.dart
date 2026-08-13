import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/widgets/reader_shortcuts.dart';

void main() {
  testWidgets('Home key fires onScrollToTop', (tester) async {
    var fired = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderShortcuts(
          onScrollToTop: () => fired = true,
          child: const Scaffold(body: Text('test')),
        ),
      ),
    );
    await tester.pump(); // let the post-frame focus request run

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();

    expect(fired, isTrue);
  });

  testWidgets('onScrollToTop null does not crash on Home', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderShortcuts(
          child: Scaffold(body: Text('test')),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    // No exception = pass
  });

  test('ScrollToTopIntent exists', () {
    expect(const ScrollToTopIntent(), isA<ScrollToTopIntent>());
  });
}
