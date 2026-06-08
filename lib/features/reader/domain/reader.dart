import 'dart:typed_data';

enum ReaderTheme { light, dark, sepia }

enum ReaderMode { paginated, continuous }

class ReaderSettings {
  final ReaderTheme theme;
  final ReaderMode mode;
  final double fontSize;
  final double lineHeight;
  final double margin;

  const ReaderSettings({
    this.theme = ReaderTheme.light,
    this.mode = ReaderMode.paginated,
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.margin = 16.0,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderMode? mode,
    double? fontSize,
    double? lineHeight,
    double? margin,
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
