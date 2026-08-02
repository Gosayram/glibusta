import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arrow key navigation focus isolation', () {
    testWidgets('Down arrow moves between sidebar items only', (tester) async {
      // Mirrors sectioned sidebar: 8 focusable ListTiles across 3 sections
      final focusNodes = List.generate(8, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    children: [
                      // Section header: Обзор (non-focusable Text)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Обзор'),
                      ),
                      Focus(focusNode: focusNodes[0], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[1], child: const SizedBox(width: 100, height: 40)),
                      // Section header: Библиотека
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Библиотека'),
                      ),
                      Focus(focusNode: focusNodes[2], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[3], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[4], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[5], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[6], child: const SizedBox(width: 100, height: 40)),
                      Focus(focusNode: focusNodes[7], child: const SizedBox(width: 100, height: 40)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(
                      children: List.generate(
                        4,
                        (i) => Focus(
                          child: SizedBox(key: Key('content_$i'), width: 200, height: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      focusNodes[0].requestFocus();
      await tester.pump();

      for (var i = 1; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusNodes[i].hasFocus, isTrue, reason: 'should focus item $i');
      }

      // Down at last item stays in sidebar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusNodes[7].hasFocus, isTrue, reason: 'should not leave sidebar');
    });

    testWidgets('Right arrow from sidebar moves to content', (tester) async {
      final sidebarNodes = List.generate(5, (_) => FocusNode());
      final contentNodes = List.generate(3, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          FocusScope.of(node.context!).nextFocus();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Обзор'),
                        ),
                        Focus(
                          focusNode: sidebarNodes[0],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                        Focus(
                          focusNode: sidebarNodes[1],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Библиотека'),
                        ),
                        Focus(
                          focusNode: sidebarNodes[2],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                        Focus(
                          focusNode: sidebarNodes[3],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                        Focus(
                          focusNode: sidebarNodes[4],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(
                      children: List.generate(
                        3,
                        (i) => Focus(
                          focusNode: contentNodes[i],
                          child: const SizedBox(width: 200, height: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      sidebarNodes[4].requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      // Right from sidebar should move to content area
      final contentFocused = contentNodes.any((n) => n.hasFocus);
      expect(contentFocused, isTrue, reason: 'Right from sidebar should focus content');
    });

    testWidgets('Left arrow in sidebar stays in sidebar', (tester) async {
      final focusNodes = List.generate(3, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        return KeyEventResult.ignored;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      children: List.generate(
                        3,
                        (i) => Focus(
                          focusNode: focusNodes[i],
                          child: const SizedBox(width: 100, height: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: const SizedBox(width: 200, height: 200),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      focusNodes[0].requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(focusNodes[0].hasFocus, isTrue, reason: 'Left should stay in sidebar');
    });

    testWidgets('Section headers are not focusable', (tester) async {
      // Section headers are plain Text widgets — no Focus, so traversal skips them
      final focusNodes = List.generate(4, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Обзор'),
                  ),
                  Focus(focusNode: focusNodes[0], child: const SizedBox(width: 100, height: 40)),
                  Focus(focusNode: focusNodes[1], child: const SizedBox(width: 100, height: 40)),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Библиотека'),
                  ),
                  Focus(focusNode: focusNodes[2], child: const SizedBox(width: 100, height: 40)),
                  Focus(focusNode: focusNodes[3], child: const SizedBox(width: 100, height: 40)),
                ],
              ),
            ),
          ),
        ),
      );

      focusNodes[0].requestFocus();
      await tester.pump();

      // Down should go directly to focusNodes[1], skipping the "Обзор" header
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusNodes[1].hasFocus, isTrue, reason: 'should skip section header');

      // Continue down — skip "Библиотека" header, land on focusNodes[2]
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusNodes[2].hasFocus, isTrue, reason: 'should skip second section header');
    });

    testWidgets('Down arrow at last sidebar item stays in sidebar', (tester) async {
      final focusNodes = List.generate(3, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    children: List.generate(
                      3,
                      (i) => Focus(
                        focusNode: focusNodes[i],
                        child: const SizedBox(width: 100, height: 40),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(
                      children: List.generate(
                        3,
                        (i) => Focus(
                          child: SizedBox(key: Key('content_$i'), width: 200, height: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Focus the last sidebar item
      focusNodes[2].requestFocus();
      await tester.pump();

      // Down arrow should stay on the last item, not escape to content
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusNodes[2].hasFocus, isTrue, reason: 'Down at last item should stay');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusNodes[2].hasFocus, isTrue, reason: 'Still should not leave sidebar');
    });

    testWidgets('Tab moves from sidebar to content', (tester) async {
      final sidebarNode = FocusNode();
      final contentNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Focus(
                    focusNode: sidebarNode,
                    child: const SizedBox(width: 100, height: 40),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Focus(
                      focusNode: contentNode,
                      child: const SizedBox(width: 200, height: 40),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      sidebarNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(contentNode.hasFocus, isTrue);
    });

    testWidgets('Down arrow in grid moves to next row', (tester) async {
      final focusNodes = List.generate(6, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (i) => Focus(
                        focusNode: focusNodes[i],
                        child: const SizedBox(width: 100, height: 80),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Focus(
                        focusNode: focusNodes[i + 3],
                        child: const SizedBox(width: 100, height: 80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      focusNodes[0].requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(focusNodes[3].hasFocus, isTrue);
    });

    testWidgets('Right arrow in grid moves to next card in row', (tester) async {
      final focusNodes = List.generate(3, (_) => FocusNode());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Row(
                children: List.generate(
                  3,
                  (i) => Focus(
                    focusNode: focusNodes[i],
                    child: const SizedBox(width: 100, height: 80),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      focusNodes[0].requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(focusNodes[1].hasFocus, isTrue);
    });

    testWidgets('Enter activates focused item', (tester) async {
      var activated = false;
      final focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Focus(
                focusNode: focusNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    activated = true;
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: const SizedBox(width: 100, height: 80),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(activated, isTrue);
    });
  });
}
