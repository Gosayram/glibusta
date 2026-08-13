import 'dart:math' as math;

/// The narrowest column that remains comfortable for a paginated spread.
const double minimumReaderSpreadColumnWidth = 320;

/// Decides whether a two-page preference is readable in the current layout.
///
/// A stored spread preference is not discarded when this returns false. It is
/// applied again when the window widens or the effective text size decreases.
bool shouldUseTwoPageReaderLayout({
  required bool preferenceEnabled,
  required bool deviceSupportsTwoPageMode,
  required double contentWidth,
  required double scaledFontSize,
}) {
  if (!preferenceEnabled || !deviceSupportsTwoPageMode) return false;

  final minimumColumnWidth = math.max(
    minimumReaderSpreadColumnWidth,
    scaledFontSize * 20,
  );
  final columnWidth = (contentWidth - 1) / 2;
  return columnWidth >= minimumColumnWidth;
}
