/// Shared bounds and actions for the fixed-layout DjVu viewport.
abstract final class DjvuZoom {
  static const min = 1.0;
  static const max = 5.0;
  static const step = 0.5;

  static double zoomIn(double current) => _bound(current + step);

  static double zoomOut(double current) => _bound(current - step);

  static double reset() => min;

  static double _bound(double value) => value.clamp(min, max);
}
