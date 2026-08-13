import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/djvu_zoom.dart';

void main() {
  group('DjvuZoom', () {
    test('uses accessible half-step zoom actions within the fixed-layout bounds', () {
      expect(DjvuZoom.zoomIn(DjvuZoom.min), 1.5);
      expect(DjvuZoom.zoomOut(1.5), DjvuZoom.min);
      expect(DjvuZoom.zoomIn(DjvuZoom.max), DjvuZoom.max);
      expect(DjvuZoom.zoomOut(DjvuZoom.min), DjvuZoom.min);
    });

    test('resets the next page viewport to its readable fit', () {
      expect(DjvuZoom.reset(), DjvuZoom.min);
    });
  });
}
