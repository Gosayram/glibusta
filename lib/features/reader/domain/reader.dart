import 'dart:typed_data';

enum ReaderTheme { light, dark, sepia, oledBlack, paper }

enum ReaderMode { paginated, continuous, twoPage, focus, fullscreen }

enum ReaderFont {
  literata('Literata'),
  merriweather('Merriweather'),
  sourceSerif('Source Serif'),
  robotoSerif('Roboto Serif');

  const ReaderFont(this.displayName);
  final String displayName;
}

enum ReaderTextAlign {
  left('По левому краю'),
  justify('По ширине'),
  center('По центру'),
  right('По правому краю');

  const ReaderTextAlign(this.displayName);
  final String displayName;
}

class ReaderSettings {
  final ReaderTheme theme;
  final ReaderMode mode;
  final double fontSize;
  final double lineHeight;
  final double margin;
  final ReaderFont font;
  final double paragraphSpacing;
  final double letterSpacing;
  final ReaderTextAlign textAlign;

  const ReaderSettings({
    this.theme = ReaderTheme.light,
    this.mode = ReaderMode.paginated,
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.margin = 16.0,
    this.font = ReaderFont.literata,
    this.paragraphSpacing = 8.0,
    this.letterSpacing = 0.0,
    this.textAlign = ReaderTextAlign.justify,
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    ReaderMode? mode,
    double? fontSize,
    double? lineHeight,
    double? margin,
    ReaderFont? font,
    double? paragraphSpacing,
    double? letterSpacing,
    ReaderTextAlign? textAlign,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      mode: mode ?? this.mode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
      font: font ?? this.font,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textAlign: textAlign ?? this.textAlign,
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

class ReadingProfile {
  final String name;
  final ReaderSettings settings;

  const ReadingProfile({required this.name, required this.settings});

  static const defaults = <ReadingProfile>[
    ReadingProfile(
      name: 'Стандартный',
      settings: ReaderSettings(),
    ),
    ReadingProfile(
      name: 'Комфортный',
      settings: ReaderSettings(
        fontSize: 20.0,
        lineHeight: 1.8,
        margin: 24.0,
        paragraphSpacing: 12.0,
        font: ReaderFont.merriweather,
        theme: ReaderTheme.sepia,
      ),
    ),
    ReadingProfile(
      name: 'Компактный',
      settings: ReaderSettings(
        fontSize: 13.0,
        lineHeight: 1.3,
        margin: 8.0,
        paragraphSpacing: 4.0,
        letterSpacing: -0.3,
      ),
    ),
    ReadingProfile(
      name: 'Ночной',
      settings: ReaderSettings(
        fontSize: 18.0,
        lineHeight: 1.6,
        margin: 20.0,
        paragraphSpacing: 10.0,
        theme: ReaderTheme.oledBlack,
      ),
    ),
  ];
}

abstract class BookParser {
  Future<String> parseFb2(Uint8List bytes);
  Future<String> parseEpub(Uint8List bytes);
  Future<String> parseTxt(Uint8List bytes);
}
