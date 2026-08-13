import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/domain/reader.dart';
import 'package:glibusta/features/reader/presentation/reader_corner_tap.dart';

void main() {
  const readerSize = Size(400, 800);

  group('cornerTapActionAt', () {
    test('resolves each physical corner to its independently configured action', () {
      const settings = ReaderSettings(
        topLeftCornerTapAction: CornerTapAction.previousPage,
        topRightCornerTapAction: CornerTapAction.nextPage,
        bottomLeftCornerTapAction: CornerTapAction.addBookmark,
        bottomRightCornerTapAction: CornerTapAction.toggleUi,
      );

      expect(
        cornerTapActionAt(settings: settings, position: const Offset(10, 10), size: readerSize),
        CornerTapAction.previousPage,
      );
      expect(
        cornerTapActionAt(settings: settings, position: const Offset(390, 10), size: readerSize),
        CornerTapAction.nextPage,
      );
      expect(
        cornerTapActionAt(settings: settings, position: const Offset(10, 790), size: readerSize),
        CornerTapAction.addBookmark,
      );
      expect(
        cornerTapActionAt(settings: settings, position: const Offset(390, 790), size: readerSize),
        CornerTapAction.toggleUi,
      );
    });

    test('leaves non-corner taps and default corners to existing tap handling', () {
      const settings = ReaderSettings();

      expect(
        cornerTapActionAt(settings: settings, position: const Offset(200, 400), size: readerSize),
        isNull,
      );
      expect(
        cornerTapActionAt(settings: settings, position: const Offset(10, 10), size: readerSize),
        CornerTapAction.inherit,
      );
    });
  });
}
