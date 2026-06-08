// ignore_for_file: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ReaderTheme { light, dark, sepia }

enum ReaderMode { paginated, continuous }

@immutable
class ReaderSettings {
  final ReaderTheme theme;
  final ReaderMode mode;
  final double fontSize;
  final double lineHeight;
  final EdgeInsets margin;

  const ReaderSettings({
    this.theme = ReaderTheme.light,
    this.mode = ReaderMode.paginated,
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.margin = const EdgeInsets.all(16.0),
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderMode? mode,
    double? fontSize,
    double? lineHeight,
    EdgeInsets? margin,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      mode: mode ?? this.mode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
    );
  }
}

@immutable
class ReadingProgress {
  final String bookId;
  final int currentPosition;
  final DateTime lastRead;

  const ReadingProgress({
    required this.bookId,
    required this.currentPosition,
    required this.lastRead,
  });
}

abstract class BookParser {
  Future<String> parseFb2(Uint8List bytes);
  Future<String> parseEpub(Uint8List bytes);
  Future<String> parseTxt(Uint8List bytes);
}