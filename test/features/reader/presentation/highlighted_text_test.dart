import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/presentation/highlighted_text.dart';

void main() {
  testWidgets('lays out a Persian selection using RTL geometry', (tester) async {
    final highlight = TextHighlight(
      id: 'highlight-1',
      bookId: 'book-1',
      chapterId: 'chapter-1',
      chapterIndex: 0,
      blockIndex: 0,
      startOffset: 0,
      endOffset: 5,
      selectedText: 'فارسی',
      color: 'yellow',
      decoration: 'none',
      isOrphaned: false,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HighlightedText(
            text: 'فارسی',
            style: const TextStyle(color: Colors.black, fontSize: 24),
            textAlign: TextAlign.start,
            highlights: [highlight],
          ),
        ),
      ),
    );

    expect(find.text('فارسی'), findsOneWidget);
    final painter = TextPainter(
      text: const TextSpan(text: 'فارسی', style: TextStyle(fontSize: 24)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 240);
    addTearDown(painter.dispose);

    final rects = highlightRectsForSelection(painter, highlight.startOffset, highlight.endOffset);
    expect(rects, hasLength(1));
    final expected = painter
        .getBoxesForSelection(
          TextSelection(baseOffset: highlight.startOffset, extentOffset: highlight.endOffset),
        )
        .single
        .toRect();
    expect(rects.single.left, expected.left - 2);
    expect(rects.single.top, expected.top + 2);
  });

  testWidgets('keeps a wrapped Persian highlight on its visual line', (tester) async {
    const text = 'یک دو سه چهار پنج شش هفت هشت نه ده';
    final start = text.indexOf('نه');
    final highlight = TextHighlight(
      id: 'highlight-wrapped',
      bookId: 'book-1',
      chapterId: 'chapter-1',
      chapterIndex: 0,
      blockIndex: 0,
      startOffset: start,
      endOffset: start + 'نه'.length,
      selectedText: 'نه',
      color: 'yellow',
      decoration: 'none',
      isOrphaned: false,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: HighlightedText(
              text: text,
              style: const TextStyle(color: Colors.black, fontSize: 24),
              textAlign: TextAlign.start,
              highlights: [highlight],
            ),
          ),
        ),
      ),
    );

    final painter = TextPainter(
      text: const TextSpan(text: text, style: TextStyle(fontSize: 24)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 100);
    addTearDown(painter.dispose);

    final rects = highlightRectsForSelection(painter, highlight.startOffset, highlight.endOffset);
    expect(rects, hasLength(1));
    expect(rects.single.top, greaterThan(30));
  });
}
