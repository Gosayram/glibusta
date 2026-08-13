import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextPainter reuse', () {
    late TextPainter painter;

    setUp(() {
      painter = TextPainter(textDirection: TextDirection.ltr);
    });

    tearDown(() {
      painter.dispose();
    });

    test('same text produces same height', () {
      const style = TextStyle(fontSize: 16, height: 1.5);
      const text = 'Hello world, this is a test paragraph for measuring.';

      painter
        ..text = const TextSpan(text: text, style: style)
        ..layout(maxWidth: 300);
      final h1 = painter.height;

      painter
        ..text = const TextSpan(text: text, style: style)
        ..layout(maxWidth: 300);
      final h2 = painter.height;

      expect(h1, equals(h2));
    });

    test('different text produces different height', () {
      const style = TextStyle(fontSize: 16, height: 1.5);
      const short = 'Hi';
      const long =
          'This is a significantly longer paragraph that should wrap '
          'across multiple lines when measured at a constrained width, '
          'producing a taller measured height than the short text.';

      painter
        ..text = const TextSpan(text: short, style: style)
        ..layout(maxWidth: 300);
      final hShort = painter.height;

      painter
        ..text = const TextSpan(text: long, style: style)
        ..layout(maxWidth: 300);
      final hLong = painter.height;

      expect(hLong, greaterThan(hShort));
    });

    test('different maxWidth produces different height', () {
      const style = TextStyle(fontSize: 16, height: 1.5);
      const text =
          'A moderately long piece of text that will wrap differently '
          'depending on the available width constraint given to layout.';

      painter
        ..text = const TextSpan(text: text, style: style)
        ..layout(maxWidth: 200);
      final hNarrow = painter.height;

      painter
        ..text = const TextSpan(text: text, style: style)
        ..layout(maxWidth: 600);
      final hWide = painter.height;

      expect(hNarrow, greaterThan(hWide));
    });

    test('different font size produces different height', () {
      const text = 'Same text, different size.';

      painter
        ..text = const TextSpan(
          text: text,
          style: TextStyle(fontSize: 12, height: 1.5),
        )
        ..layout(maxWidth: 300);
      final hSmall = painter.height;

      painter
        ..text = const TextSpan(
          text: text,
          style: TextStyle(fontSize: 24, height: 1.5),
        )
        ..layout(maxWidth: 300);
      final hLarge = painter.height;

      expect(hLarge, greaterThan(hSmall));
    });

    test('many sequential layouts with same text stay consistent', () {
      const style = TextStyle(fontSize: 16, height: 1.5);
      const text = 'Repeated measurement test paragraph.';

      painter
        ..text = const TextSpan(text: text, style: style)
        ..layout(maxWidth: 300);
      final expected = painter.height;

      for (var i = 0; i < 100; i++) {
        painter
          ..text = const TextSpan(text: text, style: style)
          ..layout(maxWidth: 300);
        expect(painter.height, equals(expected));
      }
    });
  });
}
