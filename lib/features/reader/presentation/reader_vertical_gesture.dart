/// Converts a vertical drag distance to a bounded reader brightness value.
double readerBrightnessForVerticalDrag({
  required double startBrightness,
  required double deltaY,
}) => (startBrightness - deltaY / 500).clamp(0.2, 1.0);

/// Converts a vertical drag distance to a bounded reader warmth value.
double readerWarmthForVerticalDrag({
  required double startWarmth,
  required double deltaY,
}) => (startWarmth - deltaY / 500).clamp(0.0, 1.0);
