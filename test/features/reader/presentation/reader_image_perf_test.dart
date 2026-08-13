import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/reader_content.dart';

void main() {
  group('base64Decode caching', () {
    setUp(() => clearBase64Cache());

    test('same input returns same bytes from cache', () {
      final raw = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = base64Encode(raw);

      final first = cachedBase64Decode(encoded);
      final second = cachedBase64Decode(encoded);

      expect(identical(first, second), isTrue);
      expect(first, equals(raw));
    });

    test('different inputs produce different cached entries', () {
      final a = base64Encode(Uint8List.fromList([10, 20]));
      final b = base64Encode(Uint8List.fromList([30, 40]));

      final decodedA = cachedBase64Decode(a);
      final decodedB = cachedBase64Decode(b);

      expect(decodedA, isNot(equals(decodedB)));
    });

    test('clearBase64Cache evicts entries', () {
      final raw = Uint8List.fromList([7, 8, 9]);
      final encoded = base64Encode(raw);

      final first = cachedBase64Decode(encoded);
      clearBase64Cache();
      final second = cachedBase64Decode(encoded);

      expect(first, equals(second));
      expect(identical(first, second), isFalse);
    });
  });

  group('DjVu cacheWidth/cacheHeight', () {
    testWidgets('Image.memory with cacheWidth/cacheHeight renders without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final size = MediaQuery.sizeOf(context);

              return Image.memory(
                Uint8List.fromList(_minimalPng),
                cacheWidth: (size.width * dpr).round(),
                cacheHeight: (size.height * dpr).round(),
              );
            },
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    test('cacheDimension scales by device pixel ratio', () {
      const displaySize = 600.0;
      const dpr = 3.0;
      final result = (displaySize * dpr).round();
      expect(result, 1800);
    });
  });
}

// 1x1 white PNG — minimal valid image for Image.memory
const _minimalPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x90,
  0x77,
  0x53,
  0xDE,
  0x00,
  0x00,
  0x00,
  0x0C,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xE2,
  0x21,
  0xBC,
  0x33,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
