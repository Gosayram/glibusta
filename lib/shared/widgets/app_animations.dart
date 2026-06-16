import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Extension methods for applying reusable animation presets.
///
/// Usage:
/// ```dart
/// widget.animate().fadeIn().slideX();
/// // or with presets:
/// widget.animate().bookCardTransition();
/// ```
extension AppAnimationsExt on Animate {
  /// Book card appearing in a horizontal or vertical list.
  Animate bookCardTransition({Duration? delay}) =>
      fadeIn(delay: delay, duration: 300.ms).slideX(begin: 0.05, delay: delay, duration: 300.ms);

  /// Section header fading in.
  Animate sectionFadeIn({Duration? delay}) => fadeIn(delay: delay, duration: 300.ms);

  /// List tile (bookmark, note, quote, series) appearing.
  Animate listTileTransition({Duration? delay}) =>
      fadeIn(delay: delay, duration: 300.ms).slideX(begin: 0.03, delay: delay, duration: 300.ms);

  /// Book card in a series detail grid.
  Animate seriesBookCardTransition({Duration? delay}) => fadeIn(
    delay: delay,
    duration: 400.ms,
  ).scale(begin: const Offset(0.95, 0.95), delay: delay, duration: 400.ms);

  /// Entire content block fading in (book details page).
  Animate contentFadeIn({Duration? delay}) => fadeIn(delay: delay, duration: 400.ms);

  /// Genre grid card — fast fade for dense grids.
  Animate genreCardFadeIn({Duration? delay}) => fadeIn(delay: delay, duration: 200.ms);

  /// Author list item — compact fade.
  Animate authorListItemFadeIn({Duration? delay}) => fadeIn(delay: delay, duration: 250.ms);
}
