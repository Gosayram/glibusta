import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_corner_long_press.dart';

void main() {
  const readerSize = Size(400, 800);

  group('cornerLongPressActionAt', () {
    test('resolves independently configured physical corners', () {
      const settings = ReaderSettings(
        topLeftCornerLongPressAction: CornerLongPressAction.previousPage,
        topRightCornerLongPressAction: CornerLongPressAction.nextPage,
        bottomLeftCornerLongPressAction: CornerLongPressAction.addBookmark,
        bottomRightCornerLongPressAction: CornerLongPressAction.toggleUi,
      );

      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(10, 10),
          size: readerSize,
        ),
        CornerLongPressAction.previousPage,
      );
      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(390, 10),
          size: readerSize,
        ),
        CornerLongPressAction.nextPage,
      );
      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(10, 790),
          size: readerSize,
        ),
        CornerLongPressAction.addBookmark,
      );
      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(390, 790),
          size: readerSize,
        ),
        CornerLongPressAction.toggleUi,
      );
    });

    test('leaves the text area and default corners to selection', () {
      const settings = ReaderSettings();

      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(200, 400),
          size: readerSize,
        ),
        isNull,
      );
      expect(
        cornerLongPressActionAt(
          settings: settings,
          position: const Offset(10, 10),
          size: readerSize,
        ),
        CornerLongPressAction.inherit,
      );
    });
  });

  testWidgets('only configured corners receive a long-press recognizer', (tester) async {
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: ReaderCornerLongPressOverlay(
            settings: const ReaderSettings(
              topLeftCornerLongPressAction: CornerLongPressAction.addBookmark,
            ),
            onAction: (_) => actionCount++,
            child: const SelectionArea(child: Text('Selectable text')),
          ),
        ),
      ),
    );

    final gestureDetectors = tester.widgetList<GestureDetector>(find.byType(GestureDetector));
    expect(gestureDetectors.where((gesture) => gesture.onLongPress != null), hasLength(1));

    await tester.longPressAt(const Offset(10, 10));
    expect(actionCount, 1);
  });

  testWidgets('default corners do not add a recognizer over selectable text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderCornerLongPressOverlay(
          settings: ReaderSettings(),
          onAction: _ignoreAction,
          child: SelectionArea(child: Text('Selectable text')),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNothing);
  });
}

void _ignoreAction(CornerLongPressAction _) {}
