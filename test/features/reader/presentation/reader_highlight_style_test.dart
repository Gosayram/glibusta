import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/data/highlight_decoration.dart';
import 'package:glibusta/features/reader/presentation/highlighted_text.dart';

void main() {
  group('HighlightDecoration', () {
    test('enum has all expected values', () {
      expect(HighlightDecoration.values, hasLength(3));
      expect(HighlightDecoration.none, isNotNull);
      expect(HighlightDecoration.underline, isNotNull);
      expect(HighlightDecoration.strikethrough, isNotNull);
    });

    test('toDbValue returns correct strings', () {
      expect(HighlightDecoration.none.toDbValue(), 'none');
      expect(HighlightDecoration.underline.toDbValue(), 'underline');
      expect(HighlightDecoration.strikethrough.toDbValue(), 'strikethrough');
    });

    test('fromDbValue parses valid values', () {
      expect(HighlightDecoration.fromDbValue('none'), HighlightDecoration.none);
      expect(HighlightDecoration.fromDbValue('underline'), HighlightDecoration.underline);
      expect(
        HighlightDecoration.fromDbValue('strikethrough'),
        HighlightDecoration.strikethrough,
      );
    });

    test('fromDbValue falls back to none for unknown', () {
      expect(HighlightDecoration.fromDbValue(null), HighlightDecoration.none);
      expect(HighlightDecoration.fromDbValue('invalid'), HighlightDecoration.none);
    });

    test('toTextDecoration returns correct Flutter decorations', () {
      expect(HighlightDecoration.none.toTextDecoration(), TextDecoration.none);
      expect(HighlightDecoration.underline.toTextDecoration(), TextDecoration.underline);
      expect(
        HighlightDecoration.strikethrough.toTextDecoration(),
        TextDecoration.lineThrough,
      );
    });
  });

  group('HighlightedText decoration rendering', () {
    TextHighlight makeHighlight(String deco, {int start = 0, int end = 4}) => TextHighlight(
      id: 'hl-1',
      bookId: 'book-1',
      chapterId: 'ch-1',
      chapterIndex: 0,
      blockIndex: 0,
      startOffset: start,
      endOffset: end,
      selectedText: 'Test',
      color: 'yellow',
      decoration: deco,
      isOrphaned: false,
      createdAt: DateTime.utc(2026),
    );

    TextSpan? findHighlightedTextSpan(WidgetTester tester) {
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final w in textWidgets) {
        final span = w.textSpan;
        if (span is TextSpan && span.children != null && span.children!.isNotEmpty) {
          return span;
        }
      }
      return null;
    }

    testWidgets('applies underline decoration to highlighted text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            child: HighlightedText(
              text: 'Test text',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.start,
              highlights: [makeHighlight('underline')],
            ),
          ),
        ),
      );

      final span = findHighlightedTextSpan(tester);
      expect(span, isNotNull);
      final firstChild = span!.children!.first as TextSpan;
      expect(firstChild.style!.decoration, TextDecoration.underline);
    });

    testWidgets('applies strikethrough decoration to highlighted text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            child: HighlightedText(
              text: 'Test text',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.start,
              highlights: [makeHighlight('strikethrough')],
            ),
          ),
        ),
      );

      final span = findHighlightedTextSpan(tester);
      expect(span, isNotNull);
      final firstChild = span!.children!.first as TextSpan;
      expect(firstChild.style!.decoration, TextDecoration.lineThrough);
    });

    testWidgets('no decoration for none style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            child: HighlightedText(
              text: 'Test text',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.start,
              highlights: [makeHighlight('none')],
            ),
          ),
        ),
      );

      final span = findHighlightedTextSpan(tester);
      expect(span, isNotNull);
      final firstChild = span!.children!.first as TextSpan;
      expect(firstChild.style!.decoration, TextDecoration.none);
    });

    testWidgets('preserves text outside highlight range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            child: HighlightedText(
              text: 'Hello World',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.start,
              highlights: [makeHighlight('underline')],
            ),
          ),
        ),
      );

      final span = findHighlightedTextSpan(tester);
      expect(span, isNotNull);
      expect(span!.children, hasLength(2));
      final tail = span.children![1] as TextSpan;
      expect(tail.text, 'o World');
      expect(tail.style!.decoration, isNull);
    });
  });
}
