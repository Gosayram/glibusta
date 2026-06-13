import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/shared/widgets/generated_book_cover.dart';

void main() {
  group('GeneratedBookCover', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: 'Мастер и Маргарита',
              author: 'Булгаков',
              seed: 'test-seed',
            ),
          ),
        ),
      );
      expect(find.text('Мастер и Маргарита'), findsOneWidget);
    });

    testWidgets('renders author text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: 'Book',
              author: 'Author Name',
              seed: 'seed',
            ),
          ),
        ),
      );
      expect(find.text('Author Name'), findsOneWidget);
    });

    testWidgets('renders book icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: 'T',
              author: 'A',
              seed: 's',
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.book), findsOneWidget);
    });

    testWidgets('different seeds produce different colors', (tester) async {
      final colors = <Color>[];
      for (final seed in ['seed1', 'seed2', 'seed3']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GeneratedBookCover(
                title: 'T',
                author: 'A',
                seed: seed,
              ),
            ),
          ),
        );
        final box = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final gradient = box.decoration as BoxDecoration;
        colors.add(gradient.gradient!.colors.first);
      }
      expect(colors[0], isNot(equals(colors[1])));
      expect(colors[1], isNot(equals(colors[2])));
    });

    testWidgets('has AspectRatio widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: 'T',
              author: 'A',
              seed: 's',
            ),
          ),
        ),
      );
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(2 / 3, 0.01));
    });

    testWidgets('long title is truncated with maxLines', (tester) async {
      final longTitle = 'A' * 200;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: longTitle,
              author: 'Author',
              seed: 'seed',
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(longTitle));
      expect(text.maxLines, 4);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('long author is truncated with maxLines 1', (tester) async {
      final longAuthor = 'B' * 200;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeneratedBookCover(
              title: 'Title',
              author: longAuthor,
              seed: 'seed',
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(longAuthor));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
