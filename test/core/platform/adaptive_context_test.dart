import 'dart:ui';

import 'package:flutter/material.dart' show MediaQueryData;
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/platform/adaptive_context.dart';

void main() {
  group('canUseTwoPageReaderMode', () {
    test('allows an uninterrupted landscape display wide enough for a spread', () {
      const mediaQuery = MediaQueryData(size: Size(1200, 800));

      expect(canUseTwoPageReaderMode(mediaQuery), isTrue);
    });

    test('keeps a single page on a narrow or portrait display', () {
      expect(
        canUseTwoPageReaderMode(const MediaQueryData(size: Size(999, 700))),
        isFalse,
      );
      expect(
        canUseTwoPageReaderMode(const MediaQueryData(size: Size(1200, 1201))),
        isFalse,
      );
    });

    test('does not place a spread across a folding feature', () {
      const mediaQuery = MediaQueryData(
        size: Size(1200, 800),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(590, 0, 20, 800),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );

      expect(canUseTwoPageReaderMode(mediaQuery), isFalse);
    });

    test('does not mistake a camera cutout for a reader-spanning fold', () {
      const mediaQuery = MediaQueryData(
        size: Size(1200, 800),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(550, 0, 100, 30),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      expect(canUseTwoPageReaderMode(mediaQuery), isTrue);
    });
  });
}
