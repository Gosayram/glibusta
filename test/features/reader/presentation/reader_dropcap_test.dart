import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/normalized_book.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: SizedBox(width: 400, height: 800, child: child),
    ),
  );
}

NormalizedBookMetadata _meta() => const NormalizedBookMetadata(
  id: 'test',
  title: 'Test',
  authors: [],
  chapterCount: 1,
  chapterTitles: ['Chapter'],
);

ReaderSettings _settings() => const ReaderSettings(mode: ReaderMode.continuous);

void main() {
  group('LITHIUM-UNKNOWN-004 drop cap', () {
    testWidgets('renders drop cap paragraph with first letter visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: 'Chapter',
                blocks: [
                  ReaderBlock(
                    index: 0,
                    text: 'Once upon a time there was a story.',
                    hasDropCap: true,
                  ),
                ],
              ),
            },
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('paragraph without hasDropCap renders text content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ReaderContentBody(
            metadata: _meta(),
            loadedChapters: const {
              0: ReaderChapter(
                index: 0,
                title: 'Chapter',
                blocks: [
                  ReaderBlock(
                    index: 0,
                    text: 'Normal paragraph text here.',
                  ),
                ],
              ),
            },
            settings: _settings(),
            scrollController: ScrollController(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Normal paragraph text here.'), findsOneWidget);
    });

    test('hasDropCap defaults to false in fromJson', () {
      final block = ReaderBlock.fromJson({
        'index': 0,
        'text': 'Test',
        'type': 'paragraph',
      });
      expect(block.hasDropCap, isFalse);
    });

    test('hasDropCap serializes to json when true', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        hasDropCap: true,
      );
      final json = block.toJson();
      expect(json['hasDropCap'], isTrue);
    });

    test('hasDropCap omitted from json when false', () {
      const block = ReaderBlock(index: 0, text: 'Test');
      final json = block.toJson();
      expect(json.containsKey('hasDropCap'), isFalse);
    });

    test('hasDropCap preserved in withImageUrl', () {
      const block = ReaderBlock(
        index: 0,
        text: 'Test',
        hasDropCap: true,
      );
      final updated = block.withImageUrl('img.png');
      expect(updated.hasDropCap, isTrue);
    });
  });
}
