import 'package:flutter/material.dart';

enum HighlightDecoration {
  none,
  underline,
  strikethrough;

  String toDbValue() => name;

  static HighlightDecoration fromDbValue(String? value) =>
      HighlightDecoration.values.asNameMap()[value] ?? HighlightDecoration.none;

  TextDecoration toTextDecoration() => switch (this) {
    HighlightDecoration.none => TextDecoration.none,
    HighlightDecoration.underline => TextDecoration.underline,
    HighlightDecoration.strikethrough => TextDecoration.lineThrough,
  };
}
