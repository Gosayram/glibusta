import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/database/app_database.dart';
import 'package:glibusta/features/reader/presentation/highlighted_text.dart';

void main() {
  testWidgets('aligns highlighted Persian text with its RTL renderer', (tester) async {
    const boundaryKey = Key('highlight-boundary');

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
      isOrphaned: false,
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 240,
              child: RepaintBoundary(
                key: boundaryKey,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: HighlightedText(
                    text: 'فارسی',
                    style: const TextStyle(color: Colors.black, fontSize: 24),
                    textAlign: TextAlign.start,
                    highlights: [highlight],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('فارسی'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Directionality && widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final image = await boundary.toImage();
    final ByteData? rgba = await image.toByteData();
    image.dispose();

    expect(rgba, isNotNull);
    final firstHighlightPixel = _firstYellowPixelX(rgba!, image.width, image.height);
    expect(firstHighlightPixel, isNotNull);
    expect(firstHighlightPixel, greaterThan(image.width ~/ 2));
  });
}

int? _firstYellowPixelX(ByteData rgba, int width, int height) {
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final red = rgba.getUint8(offset);
      final green = rgba.getUint8(offset + 1);
      final blue = rgba.getUint8(offset + 2);
      if (red > 220 && green > 200 && blue < 230) return x;
    }
  }
  return null;
}
