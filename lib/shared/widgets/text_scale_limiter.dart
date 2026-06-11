import 'package:flutter/material.dart';

/// Limits text scale factor for UI panels (not reader).
///
/// The reader should respect the user's system text scale, but UI chrome
/// (navigation, toolbars, settings) benefits from clamping to prevent
/// layout overflow.
///
/// Usage:
/// ```dart
/// TextScaleLimiter(
///   child: MyApp(),
/// )
/// ```
class TextScaleLimiter extends StatelessWidget {
  const TextScaleLimiter({
    required this.child,
    this.minScaleFactor = 0.85,
    this.maxScaleFactor = 1.35,
    super.key,
  });

  final Widget child;
  final double minScaleFactor;
  final double maxScaleFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaler = media.textScaler.clamp(
      minScaleFactor: minScaleFactor,
      maxScaleFactor: maxScaleFactor,
    );
    return MediaQuery(
      data: media.copyWith(textScaler: scaler),
      child: child,
    );
  }
}
