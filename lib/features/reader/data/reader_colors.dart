import 'package:flutter/material.dart';

import '../domain/reader.dart';

/// The contrast information shown when users create reader colour presets.
///
/// It describes only the three colours supplied by a preset. Rich publisher
/// styles, images and text selection can still render with different colours,
/// so this intentionally does not claim an accessibility conformance level.
final class ReaderColorPreview {
  const ReaderColorPreview._({
    required this.textContrast,
    required this.linkContrast,
    required this.isApproximate,
  });

  factory ReaderColorPreview.fromColors({
    required Color background,
    required Color text,
    required Color link,
  }) {
    final effectiveBackground = Color.alphaBlend(background, Colors.white);
    return ReaderColorPreview._(
      textContrast: ReaderColorContrast.ratio(text, effectiveBackground),
      linkContrast: ReaderColorContrast.ratio(link, effectiveBackground),
      isApproximate: background.a < 1 || text.a < 1 || link.a < 1,
    );
  }

  /// Contrast of the main reader text against the selected background.
  final double textContrast;

  /// Contrast of links against the selected background.
  final double linkContrast;

  /// Whether alpha compositing made the displayed values an approximation.
  final bool isApproximate;

  /// A ready-to-use semantics label for a colour-preset preview.
  String get semanticLabel {
    final approximation = isApproximate ? ' Значения приблизительные.' : '';
    return 'Цветовая схема. Контраст текста ${_format(textContrast)} к 1. '
        'Контраст ссылок ${_format(linkContrast)} к 1.$approximation';
  }

  static String _format(double value) => value.toStringAsFixed(1);
}

/// Calculates contrast for reader colour previews without prescribing a
/// compliance grade for arbitrary user-selected colours.
abstract final class ReaderColorContrast {
  /// Returns the contrast ratio after compositing [foreground] over
  /// [background].
  static double ratio(Color foreground, Color background) {
    final effectiveForeground = Color.alphaBlend(foreground, background);
    final foregroundLuminance = effectiveForeground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

class ReaderColors {
  final Color scaffold;
  final Color text;
  final Color link;
  final Color highlight;
  final Color footnote;
  final Color accent;

  const ReaderColors({
    required this.scaffold,
    required this.text,
    required this.link,
    required this.highlight,
    required this.footnote,
    required this.accent,
  });

  /// Contrast and accessible preview data for this reader palette.
  ReaderColorPreview get preview => ReaderColorPreview.fromColors(
    background: scaffold,
    text: text,
    link: link,
  );

  factory ReaderColors.fromPreset(
    Color bgColor,
    Color fgColor, {
    Color? linkColor,
    Color? highlightColor,
  }) {
    final link = linkColor ?? Colors.blue;
    return ReaderColors(
      scaffold: bgColor,
      text: fgColor,
      link: link,
      highlight: highlightColor ?? const Color(0x40FFEB3B),
      footnote: fgColor.withValues(alpha: 0.7),
      accent: link,
    );
  }

  static const _light = ReaderColors(
    scaffold: Colors.white,
    text: Colors.black87,
    link: Color(0xFF1565C0),
    highlight: Color(0x33FFD54F),
    footnote: Color(0xFF757575),
    accent: Color(0xFF1976D2),
  );
  static const _paper = ReaderColors(
    scaffold: Color(0xFFF5F0E6),
    text: Color(0xFF3E3225),
    link: Color(0xFF6D4C41),
    highlight: Color(0x33FFB74D),
    footnote: Color(0xFF7D6553),
    accent: Color(0xFF795548),
  );
  static const _sepia = ReaderColors(
    scaffold: Color(0xFFF4ecd8),
    text: Color(0xFF5B4636),
    link: Color(0xFF795548),
    highlight: Color(0x33FFB74D),
    footnote: Color(0xFF8D7355),
    accent: Color(0xFF6D4C41),
  );
  static const _dark = ReaderColors(
    scaffold: Color(0xFF111318),
    text: Color(0xFFE6E1E5),
    link: Color(0xFF64B5F6),
    highlight: Color(0x33FFD54F),
    footnote: Color(0xFFB0BEC5),
    accent: Color(0xFF42A5F5),
  );
  static const _oled = ReaderColors(
    scaffold: Colors.black,
    text: Color(0xFFDADADA),
    link: Color(0xFF64B5F6),
    highlight: Color(0x33FFD54F),
    footnote: Color(0xFF9E9E9E),
    accent: Color(0xFF42A5F5),
  );
  static const _bedtime = ReaderColors(
    scaffold: Color(0xFF1A1612),
    text: Color(0xFFD7CDBF),
    link: Color(0xFF8D7355),
    highlight: Color(0x33FFB74D),
    footnote: Color(0xFFA89B89),
    accent: Color(0xFF6D4C41),
  );

  // ignore: prefer_constructors_over_static_methods — factory-style accessor
  static ReaderColors forTheme(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.system || ReaderTheme.light => _light,
      ReaderTheme.paper => _paper,
      ReaderTheme.sepia => _sepia,
      ReaderTheme.dark => _dark,
      ReaderTheme.oled => _oled,
      ReaderTheme.bedtime => _bedtime,
    };
  }

  static ReaderColors forThemeWithContext(ReaderTheme theme, Brightness brightness) {
    if (theme == ReaderTheme.system) {
      return brightness == Brightness.dark ? _dark : _light;
    }
    return forTheme(theme);
  }

  static Color progressColor(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.system || ReaderTheme.light => Colors.blue.shade700,
      ReaderTheme.paper => const Color(0xFF5B4636),
      ReaderTheme.sepia => const Color(0xFF5B4636),
      ReaderTheme.dark => Colors.blue.shade300,
      ReaderTheme.oled => Colors.blue.shade300,
      ReaderTheme.bedtime => const Color(0xFFD7CDBF),
    };
  }
}
