import 'package:flutter/material.dart';

import '../domain/reader.dart';

class ReaderColors {
  final Color scaffold;
  final Color text;

  const ReaderColors({required this.scaffold, required this.text});

  static const _light = ReaderColors(scaffold: Colors.white, text: Colors.black87);
  static const _paper = ReaderColors(scaffold: Color(0xFFF5F0E6), text: Color(0xFF3E3225));
  static const _sepia = ReaderColors(scaffold: Color(0xFFF4ecd8), text: Color(0xFF5B4636));
  static const _dark = ReaderColors(scaffold: Color(0xFF111318), text: Color(0xFFE6E1E5));
  static const _oled = ReaderColors(scaffold: Colors.black, text: Color(0xFFDADADA));
  static const _bedtime = ReaderColors(scaffold: Color(0xFF1A1612), text: Color(0xFFD7CDBF));

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
