abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 300);
}

abstract final class AppReaderMetrics {
  static const double phoneMargin = 20.0;
  static const double tabletMargin = 40.0;
  static const double desktopMargin = 48.0;
  static const double tabletMaxWidth = 720.0;
  static const double desktopMaxWidth = 820.0;
  static const double defaultFontSize = 18.0;
  static const double defaultLineHeight = 1.55;
}
