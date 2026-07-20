import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/adaptive_context.dart';
import '../data/parsers/normalized_book.dart';
import '../data/parsers/quiz_parser.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'fillable_field_widget.dart';
import 'highlighted_text.dart';
import 'quiz_widget.dart';

List<InlineSpan> _bionicReadingSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == ' ' || ch == '\n' || ch == '\t') {
      if (buffer.isNotEmpty) {
        _appendBionicWord(spans, buffer.toString(), style);
        buffer.clear();
      }
      spans.add(TextSpan(text: ch, style: style));
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) {
    _appendBionicWord(spans, buffer.toString(), style);
  }
  return spans;
}

void _appendBionicWord(List<InlineSpan> spans, String word, TextStyle style) {
  // Skip leading digits (e.g. "1.2" — digits are not part of the reading word)
  var start = 0;
  while (start < word.length &&
      word[start].codeUnitAt(0) >= 0x30 &&
      word[start].codeUnitAt(0) <= 0x39) {
    start++;
  }
  if (start > 0) {
    spans.add(TextSpan(text: word.substring(0, start), style: style));
  }
  final wordPart = word.substring(start);
  if (wordPart.isEmpty) return;
  final boldLen = (wordPart.length * 0.4).ceil().clamp(1, wordPart.length);
  spans.add(
    TextSpan(
      text: wordPart.substring(0, boldLen),
      style: style.copyWith(fontWeight: FontWeight.w700),
    ),
  );
  if (boldLen < wordPart.length) {
    spans.add(TextSpan(text: wordPart.substring(boldLen), style: style));
  }
}

/// Limiter vertical helpers
double _limiterTopOffset(ReaderSettings s) {
  final dimFraction = (1.0 - s.horizontalLimiterHeight).clamp(0.0, 1.0);
  final topFraction = (1.0 - s.horizontalLimiterOffset).clamp(0.0, 1.0);
  return dimFraction * topFraction;
}

double _limiterBottomOffset(ReaderSettings s) {
  final dimFraction = (1.0 - s.horizontalLimiterHeight).clamp(0.0, 1.0);
  final bottomFraction = s.horizontalLimiterOffset.clamp(0.0, 1.0);
  return dimFraction * bottomFraction;
}

ColorFilter? _imageColorFilter(ReaderSettings? s) {
  if (s == null) return null;
  return switch (s.imageColorEffect) {
    ImageColorEffect.off => null,
    ImageColorEffect.grayscale => const ColorFilter.matrix([
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    ImageColorEffect.fontColor => ColorFilter.mode(
      ReaderColors.forTheme(s.theme).text,
      BlendMode.color,
    ),
    ImageColorEffect.backgroundColor => ColorFilter.mode(
      ReaderColors.forTheme(s.theme).scaffold,
      BlendMode.color,
    ),
  };
}

// --- Shared reader block rendering (used by both continuous and paginated modes) ---

TextAlign _resolveTextAlign(ReaderTextAlign a, {TextAlign? blockAlign}) {
  return switch (a) {
    ReaderTextAlign.left => TextAlign.left,
    ReaderTextAlign.justify => TextAlign.justify,
    ReaderTextAlign.center => TextAlign.center,
    ReaderTextAlign.right => TextAlign.right,
    ReaderTextAlign.asInBook => blockAlign ?? TextAlign.justify,
  };
}

double _headingScale(int level) => switch (level) {
  1 => 1.8,
  2 => 1.5,
  3 => 1.25,
  _ => 1.1,
};
double _headingSpacing(double ps, int level) => switch (level) {
  1 => ps * 3,
  2 => ps * 2,
  _ => ps * 1.5,
};

EdgeInsets _effectiveMargin(ReaderSettings s, ReaderMode mode) {
  if (s.separateMargins) {
    return EdgeInsets.only(
      top: s.marginTop,
      bottom: s.marginBottom,
      left: s.marginLeft,
      right: s.marginRight,
    );
  }
  return EdgeInsets.all(s.margin);
}

class ReaderCtx {
  final ReaderSettings settings;
  final ReaderColors? customColors;
  final String? highlightQuery;
  final Color linkColor;
  final Brightness brightness;
  final ValueChanged<String>? onLinkTap;

  const ReaderCtx({
    required this.settings,
    this.customColors,
    this.highlightQuery,
    required this.linkColor,
    required this.brightness,
    this.onLinkTap,
  });

  ReaderColors get colors =>
      customColors ?? ReaderColors.forThemeWithContext(settings.theme, brightness);
  TextStyle get style => _readerTextStyle(settings, colors);
}

// HG-1.2: hanging punctuation — returns negative offset for paragraphs starting with quotes/brackets
double _hangingPunctuationOffset(String text, double fontSize) {
  if (text.isEmpty) return 0;
  final first = text.trimLeft();
  if (first.isEmpty) return 0;
  final ch = first[0];
  // ponytail: approximate width of hanging characters as 0.4× font size
  if (ch == '\u00AB' ||
      ch == '\u00BB' ||
      ch == '\u201C' ||
      ch == '\u201D' ||
      ch == '\u201E' ||
      ch == '\u201F' ||
      ch == '\u2018' ||
      ch == '\u2019' ||
      ch == '\u0022' ||
      ch == "\u0027" ||
      ch == '\u0060' ||
      ch == '(' ||
      ch == '[' ||
      ch == '{' ||
      ch == '\u2039' ||
      ch == '\u203A') {
    return fontSize * 0.4;
  }
  return 0;
}

// LW-10.2: current chapter for per-chapter CSS override
int? _currentChapterForCss;

TextStyle _readerTextStyle(ReaderSettings s, ReaderColors colors) {
  final fw = (s.fontWeightDelta > 0.33)
      ? FontWeight.w600
      : (s.fontWeightDelta > 0)
      ? FontWeight.w500
      : (s.fontWeightDelta < -0.33)
      ? FontWeight.w300
      : FontWeight.w400;
  // LW-10.1: apply custom CSS overrides from user
  final css = _parseCustomCss(s.customCss, chapterIndex: _currentChapterForCss);
  return TextStyle(
    fontFamily: s.font.fontFamily,
    fontSize: css['font-size'] ?? s.fontSize,
    height: css['line-height'] ?? s.lineHeight,
    color: colors.text,
    letterSpacing: css['letter-spacing'] ?? s.letterSpacing,
    fontWeight: fw,
    wordSpacing: css['word-spacing'] ?? s.wordSpacing,
    fontFeatures: [
      const FontFeature.enable('liga'),
      const FontFeature.enable('kern'),
      if (s.oldStyleFigures) const FontFeature.enable('onum'),
      if (s.smallCaps) const FontFeature.enable('smcp'),
    ],
  );
}

/// LW-10.1/10.2: parse basic CSS properties from user's customCss text.
/// Supports `/* chapter:N */` markers for per-chapter overrides.
Map<String, double> _parseCustomCss(String css, {int? chapterIndex}) {
  if (css.isEmpty) return {};

  // LW-10.2: split CSS into global + chapter-specific blocks
  final result = <String, double>{};
  final chapterPattern = RegExp(r'/\*\s*chapter:(\d+)\s*\*/');
  final sections = css.split(chapterPattern);

  // First section (before any chapter marker) = global rules
  _extractCssProperties(sections[0], result);

  // Chapter-specific sections: pattern gives [_, chapterNum, cssText, chapterNum, cssText, ...]
  if (chapterIndex != null) {
    for (var i = 1; i < sections.length - 1; i += 2) {
      final chNum = int.tryParse(sections[i]);
      final chCss = sections[i + 1];
      if (chNum == chapterIndex && chCss.isNotEmpty) {
        _extractCssProperties(chCss, result);
      }
    }
  }

  return result;
}

void _extractCssProperties(String cssBlock, Map<String, double> result) {
  final pBlock = RegExp(r'p\s*\{([^}]*)\}').firstMatch(cssBlock);
  if (pBlock == null) return;
  final body = pBlock.group(1) ?? '';
  for (final prop in body.split(';')) {
    final colon = prop.indexOf(':');
    if (colon < 0) continue;
    final name = prop.substring(0, colon).trim();
    final value = prop.substring(colon + 1).trim();
    final numMatch = RegExp(r'([\d.]+)').firstMatch(value);
    if (numMatch == null) continue;
    final num = double.tryParse(numMatch.group(1)!);
    if (num == null) continue;
    if (name == 'font-size') result['font-size'] = num;
    if (name == 'line-height') result['line-height'] = num;
    if (name == 'letter-spacing') result['letter-spacing'] = num;
    if (name == 'word-spacing') result['word-spacing'] = num;
  }
}

bool _blockNeedsExtraGap(BlockType prev, BlockType next) {
  // Paragraphs following paragraphs — standard spacing (already have padding)
  if (prev == BlockType.paragraph && next == BlockType.paragraph) return false;
  // Separator already has generous vertical padding
  if (prev == BlockType.separator || next == BlockType.separator) return false;
  // Headings/subtitles have their own top/bottom spacing
  if (next == BlockType.heading || next == BlockType.subtitle) return false;
  // Epigraphs/poems/cites have generous margins
  if (prev == BlockType.epigraph || prev == BlockType.poem || prev == BlockType.cite) return false;
  if (next == BlockType.epigraph || next == BlockType.poem || next == BlockType.cite) return false;
  // Everything else gets a small gap
  return true;
}

Widget _buildReaderBlock(
  ReaderCtx ctx,
  ReaderBlock block,
  TextAlign textAlign, {
  List<TextHighlight>? blockHighlights,
  List<String> chapterImages = const [],
}) {
  final s = ctx.settings;
  final style = ctx.style;
  switch (block.type) {
    case BlockType.heading:
      final level = block.headingLevel ?? 2;
      final scale = _headingScale(level);
      final spacing = _headingSpacing(s.paragraphSpacing, level);
      return Padding(
        padding: EdgeInsets.only(top: spacing, bottom: s.paragraphSpacing),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontSize: s.fontSize * scale, fontWeight: FontWeight.bold),
          block.textAlign ?? TextAlign.start,
        ),
      );
    case BlockType.subtitle:
      return Padding(
        padding: EdgeInsets.only(top: s.paragraphSpacing * 2, bottom: s.paragraphSpacing),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic, fontSize: s.fontSize * 1.1),
          block.textAlign ?? TextAlign.center,
        ),
      );
    case BlockType.epigraph:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 2),
        padding: EdgeInsets.symmetric(horizontal: s.margin * 0.5, vertical: 12),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic, fontSize: s.fontSize * 0.95),
          block.textAlign ?? TextAlign.end,
        ),
      );
    // HG-16.3: poems preserve line structure — no text wrapping
    case BlockType.poem:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 2),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic),
          TextAlign.center,
          softWrap: false,
        ),
      );
    case BlockType.cite:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 1.5),
        padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 12, 12),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: (style.color ?? Colors.black).withValues(alpha: 0.3),
              width: 3,
            ),
          ),
        ),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic),
          TextAlign.start,
        ),
      );
    case BlockType.textAuthor:
      return Padding(
        padding: EdgeInsetsDirectional.only(top: s.paragraphSpacing, start: s.margin),
        child: _readerHighlightedText(
          ctx,
          '— ${block.text}',
          style.copyWith(
            fontSize: s.fontSize * 0.9,
            fontStyle: FontStyle.italic,
            color: (style.color ?? Colors.black).withValues(alpha: 0.6),
          ),
          TextAlign.end,
          richSpans: block.richSpans,
        ),
      );
    case BlockType.quote:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 1.5),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: (style.color ?? Colors.black).withValues(alpha: 0.3),
              width: 3,
            ),
          ),
        ),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic),
          textAlign,
        ),
      );
    case BlockType.separator:
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 2),
        child: Center(child: Text('* * *', style: style)),
      );
    case BlockType.image:
      if (!s.showImages) return const SizedBox.shrink();
      if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
        final caption = block.imageCaption;
        final imgWidget = Padding(
          padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
          child: Align(
            alignment: switch (s.imageAlignment) {
              ImageAlignment.start => AlignmentDirectional.centerStart,
              ImageAlignment.center => Alignment.center,
              ImageAlignment.end => AlignmentDirectional.centerEnd,
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600 * s.imageWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s.imageCornerRadius),
                child: _readerImageWidget(
                  block.imageUrl!,
                  style.color,
                  s,
                  allImages: chapterImages,
                ),
              ),
            ),
          ),
        );
        if (caption != null && caption.isNotEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              imgWidget,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s.margin * 0.5),
                child: Text(
                  caption,
                  style: style.copyWith(
                    fontSize: s.fontSize * 0.8,
                    fontStyle: FontStyle.italic,
                    color: (style.color ?? Colors.black).withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        return imgWidget;
      }
      // RCE-7.4: broken image placeholder
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
        child: Center(
          child: Text(
            '[ ${block.imageAlt ?? 'image'} ]',
            style: style.copyWith(
              fontSize: s.fontSize * 0.85,
              fontStyle: FontStyle.italic,
              color: (style.color ?? Colors.black).withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    case BlockType.footnote:
      // RCE-9.4: footnote with tappable style — context unavailable here,
      // bottom sheet requires plumbing BuildContext through _buildReaderBlock.
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing / 2),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(
            fontSize: s.fontSize * 0.85,
            color: ctx.colors.footnote,
            decoration: TextDecoration.underline,
          ),
          textAlign,
        ),
      );
    case BlockType.table:
      return _readerTableBlock(block, s, style);
    case BlockType.list:
      return _readerListBlock(ctx, block, textAlign);
    case BlockType.listItem:
      return Padding(
        padding: EdgeInsetsDirectional.only(start: s.margin, bottom: s.paragraphSpacing * 0.5),
        child: _readerHighlightedText(ctx, '• ${block.text}', style, textAlign),
      );
    case BlockType.preformatted:
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(
            fontFamily: 'monospace',
            fontSize: s.fontSize * 0.9,
          ),
          textAlign,
          richSpans: block.richSpans,
        ),
      );
    case BlockType.paragraph:
      final indentValue = switch (s.paragraphIndentMode) {
        ParagraphIndentMode.asInBook when !s.ignoreBookIndent =>
          (block.textIndent != null && block.textIndent! > 0) ? block.textIndent! : 0.0,
        ParagraphIndentMode.asInBook => 0.0,
        ParagraphIndentMode.firstLine => s.paragraphFirstLineIndent,
        ParagraphIndentMode.emptyLine => 0.0,
        ParagraphIndentMode.custom => s.paragraphFirstLineIndent,
      };
      // HG-1.2: hanging punctuation — paragraphs starting with quotes/brackets get negative indent
      final hangingOffset = _hangingPunctuationOffset(block.text, s.fontSize);
      final effectiveIndent = (indentValue - hangingOffset).clamp(0.0, double.infinity);
      final bottomPadding = s.paragraphIndentMode == ParagraphIndentMode.emptyLine
          ? s.paragraphSpacing * 2
          : s.paragraphSpacing;
      // MD-1.7: white-space detection — ws:pre uses monospace, ws:nowrap prevents wrapping
      final wsMode = block.whiteSpaceMode;
      var effectiveStyle = wsMode == 'pre' ? style.copyWith(fontFamily: 'monospace') : style;
      if (block.fontSize != null) {
        effectiveStyle = effectiveStyle.copyWith(fontSize: block.fontSize);
      }
      final effectiveAlign = wsMode != null
          ? textAlign
          : (s.ignoreBookAlignment ? textAlign : (block.textAlign ?? textAlign));
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: blockHighlights != null && blockHighlights.isNotEmpty
            ? Padding(
                padding: EdgeInsetsDirectional.only(start: effectiveIndent),
                child: HighlightedText(
                  text: block.text,
                  style: effectiveStyle,
                  textAlign: effectiveAlign,
                  highlights: blockHighlights,
                ),
              )
            : _readerHighlightedText(
                ctx,
                block.text,
                effectiveStyle,
                effectiveAlign,
                richSpans: block.richSpans,
                firstLineIndent: effectiveIndent,
              ),
      );
  }
}

Widget _buildCoverPage(String coverUrl, ReaderSettings settings, TextStyle baseStyle) {
  return SizedBox.expand(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _readerImageWidget(coverUrl, baseStyle.color, settings),
      ),
    ),
  );
}

Widget _readerHighlightedText(
  ReaderCtx ctx,
  String text,
  TextStyle style,
  TextAlign textAlign, {
  List<RichSpan>? richSpans,
  double firstLineIndent = 0,
  bool softWrap = true,
}) {
  final locale = ctx.settings.hyphenation ? const Locale('ru') : null;
  final query = ctx.highlightQuery?.trim();
  if (query == null || query.isEmpty) {
    if (richSpans != null && richSpans.isNotEmpty) {
      final spans = _readerRichTextSpans(
        richSpans,
        style,
        ctx.linkColor,
        onLinkTap: ctx.onLinkTap,
        applyBookColors: _applyBookColors(ctx.settings, ctx.brightness),
      );
      if (firstLineIndent > 0) {
        spans.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndent)));
      }
      return Text.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
        locale: locale,
        softWrap: softWrap,
      );
    }
    if (ctx.settings.bionicReading) {
      final spans = _bionicReadingSpans(text, style);
      if (firstLineIndent > 0) {
        spans.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndent)));
      }
      return Text.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
        locale: locale,
        softWrap: softWrap,
      );
    }
    if (firstLineIndent > 0) {
      return Text.rich(
        TextSpan(
          children: [
            WidgetSpan(child: SizedBox(width: firstLineIndent)),
            TextSpan(text: text),
          ],
        ),
        style: style,
        textAlign: textAlign,
        locale: locale,
        softWrap: softWrap,
      );
    }
    return Text(text, style: style, textAlign: textAlign, locale: locale, softWrap: softWrap);
  }
  return Text.rich(
    TextSpan(
      children: _readerHighlightedSpans(text, style, query, highlightColor: ctx.colors.highlight),
    ),
    textAlign: textAlign,
    locale: locale,
    softWrap: softWrap,
  );
}

/// HG-17.2: convert CSS color string to Flutter Color.
/// Supports hex (#fff, #ffffff), named colors (red, blue), rgb(r,g,b).
Color? _cssColorFromString(String raw) {
  final css = raw.trim();
  if (css.startsWith('#')) {
    final hex = css.substring(1);
    final fullHex = hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex;
    final v = int.tryParse(fullHex, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
  if (css.startsWith('rgb(') && css.endsWith(')')) {
    final parts = css.substring(4, css.length - 1).split(',');
    if (parts.length < 3) return null;
    final r = int.tryParse(parts[0].trim());
    final g = int.tryParse(parts[1].trim());
    final b = int.tryParse(parts[2].trim());
    if (r == null || g == null || b == null) return null;
    return Color.fromARGB(255, r, g, b);
  }
  // ponytail: basic named colors
  return switch (css.toLowerCase()) {
    'red' => Colors.red,
    'blue' => Colors.blue,
    'green' => Colors.green,
    'black' => Colors.black,
    'white' => Colors.white,
    'gray' || 'grey' => Colors.grey,
    'yellow' => Colors.yellow,
    'orange' => Colors.orange,
    'purple' => Colors.purple,
    'pink' => Colors.pink,
    'brown' => Colors.brown,
    'navy' => const Color(0xFF000080),
    'darkred' => const Color(0xFF8B0000),
    'darkblue' => const Color(0xFF00008B),
    'darkgreen' => const Color(0xFF006400),
    'maroon' => const Color(0xFF800000),
    'teal' => const Color(0xFF008080),
    'olive' => const Color(0xFF808000),
    _ => null,
  };
}

List<InlineSpan> _readerRichTextSpans(
  List<RichSpan> richSpans,
  TextStyle baseStyle,
  Color linkColor, {
  ValueChanged<String>? onLinkTap,
  bool forMeasurement = false,
  bool applyBookColors = true,
}) {
  final spans = <InlineSpan>[];
  for (final span in richSpans) {
    if (span.lineBreak) {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }
    var spanStyle = baseStyle;
    if (span.bold) spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
    if (span.italic) spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
    if (span.code) spanStyle = spanStyle.copyWith(fontFamily: 'monospace');
    switch (span.styleName?.trim().toLowerCase()) {
      case 'strong':
      case 'bold':
        spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
        break;
      case 'emphasis':
      case 'italic':
        spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
        break;
      case 'code':
        spanStyle = spanStyle.copyWith(fontFamily: 'monospace');
        break;
      case 'strikethrough':
      case 'strike':
        spanStyle = spanStyle.copyWith(
          decoration: TextDecoration.combine([
            if (spanStyle.decoration != null) spanStyle.decoration!,
            TextDecoration.lineThrough,
          ]),
        );
        break;
      case null:
      case '':
      default:
        break;
    }
    if (span.strikethrough) {
      spanStyle = spanStyle.copyWith(
        decoration: TextDecoration.combine([
          if (spanStyle.decoration != null) spanStyle.decoration!,
          TextDecoration.lineThrough,
        ]),
      );
    }
    if (applyBookColors && span.color != null) {
      final cssColor = _cssColorFromString(span.color!);
      if (cssColor != null) spanStyle = spanStyle.copyWith(color: cssColor);
    }
    if (span.href != null) {
      spanStyle = spanStyle.copyWith(color: linkColor, decoration: TextDecoration.underline);
    }
    if (span.superscript || span.subscript) {
      final supFontSize = baseStyle.fontSize != null ? baseStyle.fontSize! * 0.7 : 12.0;
      final supStyle = spanStyle.copyWith(fontSize: supFontSize);
      // TextPainter cannot lay out WidgetSpan without placeholder dimensions.
      // Pagination only needs the text metrics, so retain the smaller glyphs
      // while omitting the visual baseline translation used by the renderer.
      if (forMeasurement) {
        spans.add(TextSpan(text: span.text, style: supStyle));
        continue;
      }
      if (span.href != null && onLinkTap != null) {
        final href = span.href!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(
                0,
                (span.superscript ? -1 : 1) * (baseStyle.fontSize ?? 16) * 0.3,
              ),
              child: GestureDetector(
                onTap: () => onLinkTap(href),
                child: Text(span.text, style: supStyle),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(
                0,
                (span.superscript ? -1 : 1) * (baseStyle.fontSize ?? 16) * 0.3,
              ),
              child: Text(span.text, style: supStyle),
            ),
          ),
        );
      }
      continue;
    }
    if (span.href != null && onLinkTap != null) {
      final href = span.href!;
      spans.add(
        TextSpan(
          text: span.text,
          style: spanStyle,
          recognizer: TapGestureRecognizer()..onTap = () => onLinkTap(href),
        ),
      );
    } else {
      spans.add(TextSpan(text: span.text, style: spanStyle));
    }
  }
  return spans;
}

bool _applyBookColors(ReaderSettings settings, Brightness brightness) {
  return switch (settings.theme) {
    ReaderTheme.dark || ReaderTheme.oled || ReaderTheme.bedtime => false,
    ReaderTheme.system => brightness != Brightness.dark,
    _ => true,
  };
}

List<InlineSpan> _readerHighlightedSpans(
  String text,
  TextStyle style,
  String query, {
  Color highlightColor = const Color(0x66FFEB3B),
}) {
  final regex = RegExp(RegExp.escape(query), caseSensitive: false);
  final matches = regex.allMatches(text).toList();
  if (matches.isEmpty) return [TextSpan(text: text, style: style)];
  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in matches) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start), style: style));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style.copyWith(backgroundColor: highlightColor),
      ),
    );
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  return spans;
}

Widget _readerImageWidget(
  String imageUrl,
  Color? errorColor,
  ReaderSettings settings, {
  List<String> allImages = const [],
}) {
  final colorFilter = _imageColorFilter(settings);
  final uri = Uri.tryParse(imageUrl);
  final isDataUri = uri != null && uri.scheme == 'data';
  final isFileUri = uri != null && uri.scheme == 'file';
  final isPlainPath = uri == null || !uri.isAbsolute;

  Widget wrap(Widget img) {
    final filtered = colorFilter != null
        ? ColorFiltered(colorFilter: colorFilter, child: img)
        : img;
    return GestureDetector(
      onTap: () => _showFullscreenImage(imageUrl, allImages: allImages),
      child: filtered,
    );
  }

  if (isDataUri) {
    final data = imageUrl.split(',');
    if (data.length == 2) {
      return wrap(
        InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(
            base64Decode(data.last),
            fit: BoxFit.contain,
            errorBuilder: (ctx, e, s) => Icon(Icons.broken_image, size: 64, color: errorColor),
          ),
        ),
      );
    }
  }
  if (isFileUri || isPlainPath) {
    final path = isFileUri ? uri.path : imageUrl;
    final isSvg = path.toLowerCase().endsWith('.svg');
    return wrap(
      InteractiveViewer(
        maxScale: 4.0,
        child: isSvg
            ? SvgPicture.file(
                File(path),
                placeholderBuilder: (_) => const SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            : Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (ctx, e, s) => Icon(Icons.broken_image, size: 64, color: errorColor),
              ),
      ),
    );
  }
  return Icon(Icons.broken_image, size: 64, color: errorColor);
}

void _showFullscreenImage(String imageUrl, {List<String> allImages = const []}) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final images = allImages.isNotEmpty ? allImages : [imageUrl];
  final initialIndex = images.indexOf(imageUrl).clamp(0, images.length - 1);
  unawaited(
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, a, b) => _FullscreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    ),
  );
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.images, this.initialIndex = 0});
  final List<String> images;
  final int initialIndex;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _fillMode = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      onDoubleTap: () => setState(() => _fillMode = !_fillMode),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => Center(
              child: InteractiveViewer(
                maxScale: 5.0,
                minScale: 0.5,
                child: _buildImage(
                  widget.images[index],
                  fit: _fillMode ? BoxFit.cover : BoxFit.contain,
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl, {BoxFit fit = BoxFit.contain}) {
    final uri = Uri.tryParse(imageUrl);
    final isDataUri = uri != null && uri.scheme == 'data';
    final isFileUri = uri != null && uri.scheme == 'file';
    final isPlainPath = uri == null || !uri.isAbsolute;

    if (isDataUri) {
      final data = imageUrl.split(',');
      if (data.length == 2) {
        try {
          return Image.memory(
            base64Decode(data.last),
            fit: fit,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.white,
            ),
          );
        } on FormatException {
          return const Icon(Icons.broken_image, size: 64, color: Colors.white);
        }
      }
    }
    if (isFileUri || isPlainPath) {
      return Image.file(
        File(isFileUri ? uri.path : imageUrl),
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image,
          size: 64,
          color: Colors.white,
        ),
      );
    }
    return const Icon(Icons.broken_image, size: 64, color: Colors.white);
  }
}

Widget _readerTableBlock(ReaderBlock block, ReaderSettings settings, TextStyle baseStyle) {
  final rows = block.tableRows;
  if (rows == null || rows.isEmpty) return const SizedBox.shrink();
  final cellStyle = baseStyle.copyWith(fontSize: settings.fontSize * 0.9);
  final headerStyle = cellStyle.copyWith(fontWeight: FontWeight.bold);
  return Padding(
    padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: (baseStyle.color ?? Colors.black).withValues(alpha: 0.15)),
        children: rows.asMap().entries.map((entry) {
          final isHeader = entry.key == 0;
          return TableRow(
            children: entry.value
                .map(
                  (cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(cell, style: isHeader ? headerStyle : cellStyle),
                  ),
                )
                .toList(),
          );
        }).toList(),
      ),
    ),
  );
}

Widget _readerListBlock(ReaderCtx ctx, ReaderBlock block, TextAlign textAlign) {
  final items = block.listItems;
  if (items == null || items.isEmpty) return const SizedBox.shrink();
  final isOrdered = block.ordered ?? false;
  final style = ctx.style;
  return Padding(
    padding: EdgeInsets.symmetric(vertical: ctx.settings.paragraphSpacing),
    child: ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final bullet = isOrdered ? '${index + 1}.' : '\u2022';
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 24, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$bullet ', style: style),
              Expanded(
                child: _readerHighlightedText(
                  ctx,
                  item.text,
                  style,
                  textAlign,
                  richSpans: item.richSpans,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

String? _bookTextDirection(NormalizedBookMetadata metadata) {
  final value = metadata.metadata?['textDirection'];
  return value is String && (value == 'ltr' || value == 'rtl') ? value : null;
}

TextDirection _readerTextDirection(
  ReaderTextDirection td,
  BuildContext context, {
  String? bookTextDirection,
}) {
  return switch (td) {
    ReaderTextDirection.ltr => TextDirection.ltr,
    ReaderTextDirection.rtl => TextDirection.rtl,
    ReaderTextDirection.auto when bookTextDirection == 'rtl' => TextDirection.rtl,
    ReaderTextDirection.auto when bookTextDirection == 'ltr' => TextDirection.ltr,
    ReaderTextDirection.auto => Directionality.of(context),
  };
}

Widget _readerLoadingPlaceholder(
  ReaderSettings settings,
  int index,
  List<String> chapterTitles,
  TextStyle style,
) {
  final title = index < chapterTitles.length ? chapterTitles[index] : 'Глава ${index + 1}';
  return Padding(
    padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: style.copyWith(fontSize: settings.fontSize * 1.4, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: settings.paragraphSpacing * 3),
        Center(
          child: SizedBox(
            width: settings.fontSize * 1.5,
            height: settings.fontSize * 1.5,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: style.color?.withValues(alpha: 0.3),
            ),
          ),
        ),
        SizedBox(height: settings.paragraphSpacing * 2),
        ...List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
            child: Container(
              height: settings.fontSize * settings.lineHeight,
              decoration: BoxDecoration(
                color: style.color?.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

List<Widget> _readerOverlays(ReaderSettings s, Color textColor, double availableHeight) {
  return [
    if (s.perceptionExpander) ...[
      Positioned(
        left: s.margin - 1,
        top: 0,
        bottom: 0,
        child: Container(width: 1, color: textColor.withValues(alpha: 0.15)),
      ),
      Positioned(
        right: s.margin - 1,
        top: 0,
        bottom: 0,
        child: Container(width: 1, color: textColor.withValues(alpha: 0.15)),
      ),
    ],
    if (s.horizontalLimiter) ...[
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: _limiterTopOffset(s) * availableHeight,
        child: ColoredBox(color: textColor.withValues(alpha: s.horizontalLimiterDimming)),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _limiterBottomOffset(s) * availableHeight,
        child: ColoredBox(color: textColor.withValues(alpha: s.horizontalLimiterDimming)),
      ),
      if (s.horizontalLimiterLines) ...[
        Positioned(
          left: s.margin,
          right: s.margin,
          top: _limiterTopOffset(s) * availableHeight,
          child: Container(height: 1, color: textColor.withValues(alpha: 0.2)),
        ),
        Positioned(
          left: s.margin,
          right: s.margin,
          bottom: _limiterBottomOffset(s) * availableHeight,
          child: Container(height: 1, color: textColor.withValues(alpha: 0.2)),
        ),
      ],
    ],
  ];
}

class ReaderContentBody extends StatefulWidget {
  const ReaderContentBody({
    super.key,
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.scrollController,
    required this.onTap,
    this.initialProgress = 0.0,
    this.initialPage = 0,
    this.highlightQuery,
    this.chapterHighlights = const <int, List<TextHighlight>>{},
    this.blockTransformers,
    this.customColors,
    this.onLinkTap,
    this.onPageChanged,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final ScrollController scrollController;
  final GestureTapUpCallback onTap;
  final double initialProgress;
  final int initialPage;
  final String? highlightQuery;
  final Map<int, List<TextHighlight>> chapterHighlights;
  final List<BlockTransformer>? blockTransformers;
  final ReaderColors? customColors;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<int>? onPageChanged;

  @override
  State<ReaderContentBody> createState() => _ReaderContentBodyState();
}

class _ReaderContentBodyState extends State<ReaderContentBody> {
  bool _didScrollToProgress = false;

  bool _isFixedLayout() {
    final meta = widget.metadata.metadata;
    if (meta == null) return false;
    return meta['isFixedLayout'] == true || meta['rendition:layout'] == 'pre-paginated';
  }

  @override
  void didUpdateWidget(covariant ReaderContentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProgress != oldWidget.initialProgress) {
      _didScrollToProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    // LW-8.1: fixed-layout override — each spine item is a full page
    if (_isFixedLayout()) {
      return _FixedLayoutBody(
        metadata: widget.metadata,
        loadedChapters: widget.loadedChapters,
        settings: settings,
        initialPage: widget.initialPage,
        onTap: widget.onTap,
        onPageChanged: widget.onPageChanged,
      );
    }
    if (settings.mode == ReaderMode.paginated) {
      return _PaginatedContentBody(
        metadata: widget.metadata,
        loadedChapters: widget.loadedChapters,
        settings: settings,
        onTap: widget.onTap,
        initialPage: widget.initialPage,
        highlightQuery: widget.highlightQuery,
        chapterHighlights: widget.chapterHighlights,
        blockTransformers: widget.blockTransformers,
        customColors: widget.customColors,
        onLinkTap: widget.onLinkTap,
        onPageChanged: widget.onPageChanged,
      );
    }

    if (settings.mode == ReaderMode.focus) {
      return _FocusModeBody(
        metadata: widget.metadata,
        loadedChapters: widget.loadedChapters,
        settings: settings,
        initialChapterIndex: widget.initialPage,
        highlightQuery: widget.highlightQuery,
        chapterHighlights: widget.chapterHighlights,
        blockTransformers: widget.blockTransformers,
        customColors: widget.customColors,
        onLinkTap: widget.onLinkTap,
        onPageChanged: widget.onPageChanged,
      );
    }

    if (settings.mode == ReaderMode.rsvp) {
      return _RsvpModeBody(
        metadata: widget.metadata,
        loadedChapters: widget.loadedChapters,
        settings: settings,
        initialChapterIndex: widget.initialPage,
        customColors: widget.customColors,
      );
    }

    final effectiveMargin = _effectiveMargin(settings, settings.mode);
    final textDirection = _readerTextDirection(
      settings.textDirection,
      context,
      bookTextDirection: _bookTextDirection(widget.metadata),
    );
    final hasCover = widget.metadata.coverUrl != null && widget.metadata.coverUrl!.isNotEmpty;

    if (!_didScrollToProgress && widget.initialProgress > 0) {
      _didScrollToProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.scrollController.hasClients) return;
        final maxScroll = widget.scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          unawaited(
            widget.scrollController.animateTo(
              (widget.initialProgress * maxScroll).clamp(0.0, maxScroll),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          );
        }
      });
    }

    final itemCount = widget.metadata.chapterCount + (hasCover ? 1 : 0);

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: widget.onTap,
        child: Directionality(
          textDirection: textDirection,
          child: Stack(
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: (notification) {
                  if (settings.mode != ReaderMode.continuous) return false;
                  if (itemCount == 0) return false;
                  final pos = notification.metrics;
                  if (pos.maxScrollExtent <= 0) return false;
                  final avg = pos.maxScrollExtent / itemCount;
                  final target = ((pos.pixels / avg).round() * avg).clamp(0.0, pos.maxScrollExtent);
                  if ((pos.pixels - target).abs() > 8) {
                    unawaited(
                      widget.scrollController.animateTo(
                        target,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                      ),
                    );
                    return true;
                  }
                  return false;
                },
                child: ScrollConfiguration(
                  behavior: _SmoothScrollBehavior(inertia: settings.scrollInertia),
                  child: Scrollbar(
                    controller: widget.scrollController,
                    thumbVisibility: true,
                    thickness: 3,
                    radius: const Radius.circular(1.5),
                    child: ListView.builder(
                      controller: widget.scrollController,
                      padding: effectiveMargin,
                      itemCount: itemCount,
                      // ignore: deprecated_member_use
                      cacheExtent: 500,
                      addAutomaticKeepAlives: false,
                      itemBuilder: (context, index) {
                        if (hasCover && index == 0) {
                          return _buildCoverPage(
                            widget.metadata.coverUrl!,
                            settings,
                            _getReaderStyle(settings),
                          );
                        }
                        final chapterIndex = index - (hasCover ? 1 : 0);
                        final chapter = widget.loadedChapters[chapterIndex];
                        final isLast = chapterIndex == widget.metadata.chapterCount - 1;
                        final nextTitle = chapterIndex + 1 < widget.metadata.chapterTitles.length
                            ? widget.metadata.chapterTitles[chapterIndex + 1]
                            : '';
                        final dividerStyle = _getReaderStyle(settings);
                        return Column(
                          key: ValueKey('chapter-$chapterIndex'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (chapter != null)
                              _buildChapterContent(chapter, settings, chapterIndex)
                            else
                              _readerLoadingPlaceholder(
                                settings,
                                chapterIndex,
                                widget.metadata.chapterTitles,
                                _getReaderStyle(settings),
                              ),
                            if (!isLast &&
                                chapter != null &&
                                widget.loadedChapters[chapterIndex + 1] != null)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: settings.paragraphSpacing * 3,
                                ),
                                child: Center(
                                  child: Text(
                                    '— ${nextTitle.isNotEmpty ? nextTitle : "Глава ${chapterIndex + 2}"} —',
                                    style: dividerStyle.copyWith(
                                      color: dividerStyle.color?.withValues(alpha: 0.4),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              ..._readerOverlays(
                settings,
                _getReaderStyle(settings).color ?? Colors.black,
                MediaQuery.sizeOf(context).height,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterContent(ReaderChapter chapter, ReaderSettings settings, int chapterIndex) {
    // LW-10.2: set current chapter for per-chapter CSS override
    _currentChapterForCss = chapterIndex;
    final baseAlign = _resolveTextAlign(settings.textAlign);
    final isAsInBook = settings.textAlign == ReaderTextAlign.asInBook;
    final ctx = _ctx(settings);
    final chapterHighlights = widget.chapterHighlights[chapterIndex];

    final chapterImages = chapter.blocks
        .where((b) => b.type == BlockType.image && b.imageUrl != null && b.imageUrl!.isNotEmpty)
        .map((b) => b.imageUrl!)
        .toList();

    final header = chapter.title.isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
            child: _readerHighlightedText(
              ctx,
              chapter.title,
              _getReaderStyle(settings).copyWith(
                fontSize: settings.fontSize * 1.4,
                fontWeight: FontWeight.bold,
              ),
              baseAlign,
            ),
          )
        : const SizedBox.shrink();

    // LW-9.1: detect quiz groups and replace with QuizWidget
    final builtWidgets = <Widget>[];
    var skipUntil = -1;
    for (var i = 0; i < chapter.blocks.length; i++) {
      if (i <= skipUntil) continue;
      var block = chapter.blocks[i];
      var blockSkipped = false;
      if (widget.blockTransformers != null) {
        for (final t in widget.blockTransformers!) {
          final transformed = t(block);
          if (transformed == null) {
            blockSkipped = true;
            break;
          }
          block = transformed;
        }
      }
      if (blockSkipped) continue;
      // LW-9.1: Check if this block starts a quiz sequence
      if (block.text.length > 10 && block.text.contains('?')) {
        final endIdx = (i + 8).clamp(0, chapter.blocks.length);
        final texts = chapter.blocks.sublist(i, endIdx).map((b) => b.text).toList();
        final quiz = QuizParser.tryParse(texts);
        if (quiz != null && quiz.isNotEmpty) {
          builtWidgets.add(QuizWidget(blocks: quiz, key: ValueKey('quiz-$chapterIndex-$i')));
          skipUntil = i + texts.length - 1;
          continue;
        }
      }
      // LW-9.2: Check for fillable fields (___, [answer])
      if (block.text.contains('___') || block.text.contains('[') || block.text.contains('{')) {
        final endIdx = (i + 4).clamp(0, chapter.blocks.length);
        final texts = chapter.blocks.sublist(i, endIdx).map((b) => b.text).toList();
        final fillable = QuizParser.tryParseFillable(texts);
        if (fillable != null && fillable.isNotEmpty) {
          for (var fi = 0; fi < fillable.length; fi++) {
            builtWidgets.add(
              FillableFieldWidget(block: fillable[fi], key: ValueKey('fill-$chapterIndex-$i-$fi')),
            );
          }
          skipUntil = i + texts.length - 1;
          continue;
        }
      }
      builtWidgets.add(
        _buildReaderBlock(
          ctx,
          block,
          isAsInBook
              ? _resolveTextAlign(settings.textAlign, blockAlign: block.textAlign)
              : baseAlign,
          blockHighlights: chapterHighlights?.where((h) => h.blockIndex == i).toList(),
          chapterImages: chapterImages,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, ...builtWidgets],
    );
  }

  ReaderCtx _ctx(ReaderSettings settings) {
    final c =
        widget.customColors ??
        ReaderColors.forThemeWithContext(settings.theme, MediaQuery.platformBrightnessOf(context));
    return ReaderCtx(
      settings: settings,
      customColors: widget.customColors,
      highlightQuery: widget.highlightQuery,
      linkColor: c.link,
      brightness: MediaQuery.platformBrightnessOf(context),
      onLinkTap: widget.onLinkTap,
    );
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    return _readerTextStyle(
      settings,
      widget.customColors ??
          ReaderColors.forThemeWithContext(
            settings.theme,
            MediaQuery.platformBrightnessOf(context),
          ),
    );
  }
}

class _FocusModeBody extends StatelessWidget {
  const _FocusModeBody({
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.initialChapterIndex,
    this.highlightQuery,
    this.chapterHighlights,
    this.blockTransformers,
    this.customColors,
    this.onLinkTap,
    this.onPageChanged,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final int initialChapterIndex;
  static const int initialParagraphIndex = 0;
  final String? highlightQuery;
  final Map<int, List<TextHighlight>>? chapterHighlights;
  final List<BlockTransformer>? blockTransformers;
  final ReaderColors? customColors;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final blocks = <_FocusBlock>[];
    for (var ch = 0; ch < metadata.chapterCount; ch++) {
      final chapter = loadedChapters[ch];
      if (chapter == null) continue;
      for (var blk = 0; blk < chapter.blocks.length; blk++) {
        blocks.add(_FocusBlock(chapterIndex: ch, blockIndex: blk));
      }
    }

    final initialIndex = blocks.indexWhere(
      (b) => b.chapterIndex == initialChapterIndex && b.blockIndex == initialParagraphIndex,
    );
    final controller = PageController(initialPage: initialIndex >= 0 ? initialIndex : 0);

    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: blocks.length,
      onPageChanged: (index) {
        if (index < blocks.length) {
          onPageChanged?.call(blocks[index].chapterIndex);
        }
      },
      itemBuilder: (context, index) {
        final fb = blocks[index];
        final chapter = loadedChapters[fb.chapterIndex];
        if (chapter == null || fb.blockIndex >= chapter.blocks.length) {
          return const SizedBox.shrink();
        }
        final block = chapter.blocks[fb.blockIndex];
        final margin = settings.separateMargins
            ? EdgeInsets.only(
                top: settings.marginTop,
                bottom: settings.marginBottom,
                left: settings.marginLeft,
                right: settings.marginRight,
              )
            : EdgeInsets.all(settings.margin);

        final colors =
            customColors ??
            ReaderColors.forThemeWithContext(
              settings.theme,
              MediaQuery.platformBrightnessOf(context),
            );
        final readerCtx = ReaderCtx(
          settings: settings,
          customColors: customColors,
          highlightQuery: highlightQuery,
          linkColor: colors.link,
          brightness: MediaQuery.platformBrightnessOf(context),
          onLinkTap: onLinkTap,
        );

        return Padding(
          padding: margin,
          child: Center(
            child: SingleChildScrollView(
              child: _buildReaderBlock(
                readerCtx,
                block,
                block.textAlign ?? TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusBlock {
  const _FocusBlock({required this.chapterIndex, required this.blockIndex});
  final int chapterIndex;
  final int blockIndex;
}

class _PaginatedContentBody extends StatefulWidget {
  const _PaginatedContentBody({
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.onTap,
    required this.initialPage,
    this.highlightQuery,
    this.chapterHighlights = const <int, List<TextHighlight>>{},
    this.blockTransformers,
    this.customColors,
    this.onLinkTap,
    this.onPageChanged,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final GestureTapUpCallback onTap;
  final int initialPage;
  final String? highlightQuery;
  final Map<int, List<TextHighlight>> chapterHighlights;
  final List<BlockTransformer>? blockTransformers;
  final ReaderColors? customColors;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<int>? onPageChanged;

  @override
  State<_PaginatedContentBody> createState() => _PaginatedContentBodyState();
}

class _PageContent {
  final int chapterIndex;
  final int blockStart;
  final int blockEnd;
  final bool showChapterTitle;
  final bool isCover;

  const _PageContent({
    required this.chapterIndex,
    required this.blockStart,
    required this.blockEnd,
    this.showChapterTitle = false,
    this.isCover = false,
  });
}

class _PaginatedContentBodyState extends State<_PaginatedContentBody> {
  late final PageController _pageController;
  bool _didRestoreInitialPage = false;
  bool _disposed = false;
  List<_PageContent> _pages = const [];
  // HG-6.1: layout cache — avoid recomputing pages when settings haven't changed
  String? _cacheKey;
  List<_PageContent> _cachedPages = const [];
  // MD-2.3: per-chapter pagination cache — survives chapter eviction+reload
  final Map<String, List<_PageContent>> _chapterPageCache = {};
  static const int _maxCachedChapters = 30;
  // ARC-11.2: block height cache — avoid recomputing _measureTextHeight
  final Map<int, double> _heightCache = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _PaginatedContentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loadedChapters != oldWidget.loadedChapters) {
      _cacheKey = null;
      _cachedPages = const [];
      _chapterPageCache.clear();
      _heightCache.clear();
    }
    // MD-2.3: clear per-chapter cache when settings affect layout
    if (widget.settings.fontSize != oldWidget.settings.fontSize ||
        widget.settings.lineHeight != oldWidget.settings.lineHeight ||
        widget.settings.margin != oldWidget.settings.margin ||
        widget.settings.separateMargins != oldWidget.settings.separateMargins ||
        widget.settings.marginTop != oldWidget.settings.marginTop ||
        widget.settings.marginBottom != oldWidget.settings.marginBottom ||
        widget.settings.marginLeft != oldWidget.settings.marginLeft ||
        widget.settings.marginRight != oldWidget.settings.marginRight ||
        widget.settings.font != oldWidget.settings.font ||
        widget.settings.paragraphSpacing != oldWidget.settings.paragraphSpacing ||
        widget.settings.hyphenation != oldWidget.settings.hyphenation ||
        widget.settings.textAlign != oldWidget.settings.textAlign ||
        widget.settings.paragraphIndentMode != oldWidget.settings.paragraphIndentMode ||
        widget.settings.paragraphFirstLineIndent != oldWidget.settings.paragraphFirstLineIndent ||
        widget.settings.ignoreBookIndent != oldWidget.settings.ignoreBookIndent ||
        widget.settings.letterSpacing != oldWidget.settings.letterSpacing ||
        widget.settings.wordSpacing != oldWidget.settings.wordSpacing ||
        widget.settings.fontWeightDelta != oldWidget.settings.fontWeightDelta ||
        widget.settings.textDirection != oldWidget.settings.textDirection ||
        widget.settings.showImages != oldWidget.settings.showImages ||
        widget.settings.imageWidth != oldWidget.settings.imageWidth ||
        widget.settings.customCss != oldWidget.settings.customCss) {
      _chapterPageCache.clear();
      _cacheKey = null;
      _heightCache.clear();
    }
    if (widget.initialPage != oldWidget.initialPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !_pageController.hasClients) return;
        final pageCount = _pages.length;
        if (pageCount == 0) return;
        // Find first page matching the target chapter index
        final targetChapter = widget.initialPage;
        var targetPage = pageCount - 1;
        for (var i = 0; i < _pages.length; i++) {
          if (_pages[i].chapterIndex == targetChapter && !_pages[i].isCover) {
            targetPage = i;
            break;
          }
        }
        final useTwoPageLayout = widget.settings.twoPageEnabled && context.canUseTwoPageMode;
        // For two-page layout, snap to the first page in its spread.
        if (useTwoPageLayout && targetPage.isOdd) {
          targetPage = (targetPage - 1).clamp(0, pageCount - 1);
        }
        unawaited(
          _pageController.animateToPage(
            useTwoPageLayout ? targetPage ~/ 2 : targetPage,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pageController.dispose();
    super.dispose();
  }

  /// MD-2.3: paginate a single chapter, with per-chapter caching.
  List<_PageContent> _paginateSingleChapter(
    int chIdx,
    double availableHeight,
    double contentWidth,
    String settingsKey,
  ) {
    final cacheKey = '${chIdx}_$settingsKey';
    final cached = _chapterPageCache[cacheKey];
    if (cached != null) return cached;

    final settings = widget.settings;
    final chapter = widget.loadedChapters[chIdx];
    final pages = <_PageContent>[];

    if (chapter == null || chapter.blocks.isEmpty) {
      pages.add(_PageContent(chapterIndex: chIdx, blockStart: 0, blockEnd: 0));
      _chapterPageCache[cacheKey] = pages;
      _trimChapterCache();
      return pages;
    }

    const minFillRatio = 0.35;
    final titleHeight = chapter.title.isNotEmpty
        ? settings.fontSize * 1.4 * settings.lineHeight + settings.paragraphSpacing * 2
        : 0.0;
    var currentHeight = titleHeight;
    var pageStart = 0;

    for (int i = 0; i < chapter.blocks.length; i++) {
      final block = chapter.blocks[i];
      final cacheKey = _blockHeightCacheKey(block, settings, contentWidth);
      final blockHeight = _heightCache.putIfAbsent(cacheKey, () {
        return _estimateBlockHeight(block, settings, contentWidth);
      });

      if (currentHeight + blockHeight > availableHeight && i > pageStart) {
        final remainingBlocks = chapter.blocks.length - i;
        final remainingHeight = remainingBlocks > 0
            ? chapter.blocks.skip(i).fold<double>(
                0,
                (sum, b) {
                  final k = _blockHeightCacheKey(b, settings, contentWidth);
                  return sum +
                      _heightCache.putIfAbsent(k, () {
                        return _estimateBlockHeight(b, settings, contentWidth);
                      });
                },
              )
            : 0.0;
        final isOrphanPage = remainingBlocks <= 1 && remainingHeight < availableHeight * 0.25;
        if (currentHeight > availableHeight * minFillRatio && !isOrphanPage) {
          pages.add(_PageContent(chapterIndex: chIdx, blockStart: pageStart, blockEnd: i));
          pageStart = i;
          currentHeight = blockHeight;
        } else {
          currentHeight += blockHeight;
        }
      } else {
        currentHeight += blockHeight;
      }
    }

    // Final page merge
    if (pageStart > 0 &&
        pages.isNotEmpty &&
        pages.last.chapterIndex == chIdx &&
        currentHeight < availableHeight * 0.30) {
      final lastPage = pages.last;
      pages[pages.length - 1] = _PageContent(
        chapterIndex: lastPage.chapterIndex,
        blockStart: lastPage.blockStart,
        blockEnd: chapter.blocks.length,
      );
    } else {
      pages.add(
        _PageContent(chapterIndex: chIdx, blockStart: pageStart, blockEnd: chapter.blocks.length),
      );
    }

    _chapterPageCache[cacheKey] = pages;
    _trimChapterCache();
    return pages;
  }

  int _blockHeightCacheKey(ReaderBlock block, ReaderSettings settings, double contentWidth) {
    return Object.hashAll([
      block.text,
      block.type,
      block.headingLevel,
      block.textIndent,
      block.fontSize,
      block.richSpans,
      block.listItems,
      block.tableRows,
      block.imageCaption,
      settings.fontSize,
      settings.lineHeight,
      settings.font,
      settings.fontWeightDelta,
      settings.letterSpacing,
      settings.wordSpacing,
      settings.textDirection,
      settings.hyphenation,
      settings.paragraphIndentMode,
      settings.paragraphFirstLineIndent,
      settings.ignoreBookIndent,
      settings.customCss,
      settings.paragraphSpacing,
      settings.showImages,
      settings.imageWidth,
      contentWidth,
    ]);
  }

  /// Evict oldest entries when cache exceeds limit.
  void _trimChapterCache() {
    while (_chapterPageCache.length > _maxCachedChapters) {
      _chapterPageCache.remove(_chapterPageCache.keys.first);
    }
  }

  List<_PageContent> _paginateContent(double availableHeight, double contentWidth) {
    final settings = widget.settings;
    final pages = <_PageContent>[];

    // MD-2.3: per-chapter settings key for cache
    final chKey =
        '${settings.fontSize}_${settings.lineHeight}_${settings.margin}_'
        '${settings.paragraphSpacing}_${settings.letterSpacing}_${settings.paragraphFirstLineIndent}_'
        '${settings.font}_${settings.hyphenation}_${settings.textAlign.name}_'
        '${settings.paragraphIndentMode.name}_${settings.ignoreBookIndent}_'
        '${settings.wordSpacing}_${settings.fontWeightDelta}_${settings.textDirection.name}_'
        '${settings.customCss}_${settings.showImages}_${settings.imageWidth}_'
        '${availableHeight.toStringAsFixed(1)}_${contentWidth.toStringAsFixed(1)}';

    final hasCover = widget.metadata.coverUrl != null && widget.metadata.coverUrl!.isNotEmpty;
    if (hasCover) {
      pages.add(const _PageContent(chapterIndex: 0, blockStart: 0, blockEnd: 0, isCover: true));
    }

    // MD-2.3: use per-chapter cache for each chapter
    var lastChIdx = -1;
    for (int chIdx = 0; chIdx < widget.metadata.chapterCount; chIdx++) {
      final chapterPages = _paginateSingleChapter(chIdx, availableHeight, contentWidth, chKey);
      for (final p in chapterPages) {
        // Fix showChapterTitle: true for first page of each chapter
        final showTitle = chIdx != lastChIdx;
        pages.add(
          _PageContent(
            chapterIndex: p.chapterIndex,
            blockStart: p.blockStart,
            blockEnd: p.blockEnd,
            isCover: p.isCover,
            showChapterTitle: showTitle,
          ),
        );
      }
      lastChIdx = chIdx;
    }
    return pages;
  }

  /// MD-2.1: Estimate block height using layout-engine measurement.
  /// Now delegates to [_measureBlockHeight] for accurate rich-text + hyphenation.
  double _estimateBlockHeight(ReaderBlock block, ReaderSettings settings, double width) {
    final ps = settings.paragraphSpacing;
    final colors =
        widget.customColors ??
        ReaderColors.forThemeWithContext(
          settings.theme,
          MediaQuery.platformBrightnessOf(context),
        );

    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 2;
        final spacing = _headingSpacing(ps, level);
        final h = _measureBlockHeight(block, settings, colors, width);
        return h + spacing + ps;
      case BlockType.subtitle:
        return _measureBlockHeight(block, settings, colors, width) + ps * 3;
      case BlockType.epigraph:
        return _measureBlockHeight(block, settings, colors, width - settings.margin) + ps * 2 + 24;
      case BlockType.poem:
        return _measureBlockHeight(block, settings, colors, width - 48) + ps * 4;
      case BlockType.cite:
        return _measureBlockHeight(block, settings, colors, width - 40) + ps + 16;
      case BlockType.textAuthor:
        return _measureBlockHeight(block, settings, colors, width, fontScale: 0.9) + ps;
      case BlockType.quote:
        return _measureBlockHeight(block, settings, colors, width - 32) + ps + 16;
      case BlockType.separator:
        return ps * 4;
      case BlockType.image:
        if (!settings.showImages) return 0;
        if (block.imageUrl == null || block.imageUrl!.isEmpty) {
          return _measureBlockHeight(block, settings, colors, width, fontScale: 0.85) + ps;
        }
        final imgWidth = (width * settings.imageWidth).clamp(50.0, 600.0 * settings.imageWidth);
        final imgHeight = (imgWidth / 1.4).clamp(80.0, 400.0) + ps;
        if (block.imageCaption != null && block.imageCaption!.isNotEmpty) {
          final capBlock = ReaderBlock(
            text: block.imageCaption!,
            index: block.index,
          );
          return imgHeight +
              _measureBlockHeight(
                capBlock,
                settings,
                colors,
                width - settings.margin,
                fontScale: 0.8,
              ) +
              ps;
        }
        return imgHeight;
      case BlockType.footnote:
        return _measureBlockHeight(block, settings, colors, width) + ps;
      case BlockType.table:
        final rows = block.tableRows?.length ?? 0;
        return (rows * settings.fontSize * settings.lineHeight * 1.3) + ps * 2 + 16;
      case BlockType.list:
        var totalHeight = ps + 8.0;
        for (final item in block.listItems ?? <ReaderBlock>[]) {
          totalHeight += _measureBlockHeight(item, settings, colors, width - 32) + 4;
        }
        return totalHeight;
      case BlockType.listItem:
        return _measureBlockHeight(block, settings, colors, width - settings.margin) + ps * 0.5;
      case BlockType.preformatted:
        return _measureBlockHeight(block, settings, colors, width) + ps;
      case BlockType.paragraph:
        final indent = switch (settings.paragraphIndentMode) {
          ParagraphIndentMode.asInBook when !settings.ignoreBookIndent => (block.textIndent ?? 0.0),
          ParagraphIndentMode.asInBook => 0.0,
          ParagraphIndentMode.firstLine => settings.paragraphFirstLineIndent,
          ParagraphIndentMode.emptyLine => 0.0,
          ParagraphIndentMode.custom => settings.paragraphFirstLineIndent,
        };
        final bottomPad = settings.paragraphIndentMode == ParagraphIndentMode.emptyLine
            ? ps * 2
            : ps;
        return _measureBlockHeight(
              block,
              settings,
              colors,
              width,
              firstLineIndent: indent,
            ) +
            bottomPad;
    }
  }

  /// MD-2.1: Measure block height matching actual render output.
  /// Uses richSpans, locale (hyphenation), and text direction so pagination
  /// matches what the Text widget produces.
  double _measureBlockHeight(
    ReaderBlock block,
    ReaderSettings s,
    ReaderColors colors,
    double maxWidth, {
    double firstLineIndent = 0,
    double? fontScale,
  }) {
    final locale = s.hyphenation ? const Locale('ru') : null;
    final dir = switch (s.textDirection) {
      ReaderTextDirection.rtl => TextDirection.rtl,
      ReaderTextDirection.auto when _bookTextDirection(widget.metadata) == 'rtl' =>
        TextDirection.rtl,
      _ => TextDirection.ltr,
    };
    TextSpan textSpan;

    final effectiveFontScale = fontScale ?? _blockFontScale(block);
    if (block.richSpans != null && block.richSpans!.isNotEmpty) {
      final baseStyle = _readerTextStyle(s, colors).copyWith(
        fontSize: s.fontSize * effectiveFontScale,
        height: s.lineHeight,
      );
      final spans = _readerRichTextSpans(
        block.richSpans!,
        baseStyle,
        colors.link,
        forMeasurement: true,
        applyBookColors: _applyBookColors(s, MediaQuery.platformBrightnessOf(context)),
      );
      textSpan = TextSpan(children: spans);
    } else {
      final fontSize = block.fontSize ?? s.fontSize * effectiveFontScale;
      final textStyle = _readerTextStyle(s, colors).copyWith(
        fontSize: fontSize,
        height: s.lineHeight,
      );
      textSpan = TextSpan(text: block.text, style: textStyle);
    }

    final painter = TextPainter(
      text: textSpan,
      textDirection: dir,
      locale: locale,
    );
    // A WidgetSpan gives the first rendered line its indentation, but it
    // cannot be used in a standalone TextPainter. Measuring against the
    // first-line content width is conservative: it may put a page break a
    // little earlier, but never lets text overflow a page.
    final measurementWidth = firstLineIndent > 0
        ? (maxWidth - firstLineIndent).clamp(1.0, maxWidth)
        : maxWidth;
    painter.layout(maxWidth: measurementWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _blockFontScale(ReaderBlock block) {
    if (block.type == BlockType.heading) {
      final level = block.headingLevel ?? 2;
      return _headingScale(level);
    }
    if (block.type == BlockType.subtitle) {
      return 1.1;
    }
    if (block.type == BlockType.epigraph) {
      return 0.95;
    }
    if (block.type == BlockType.footnote) return 0.85;
    if (block.type == BlockType.textAuthor) return 0.9;
    if (block.type == BlockType.preformatted) {
      return 0.9;
    }
    return 1.0;
  }

  Widget _buildPaginatedPage(int index, BuildContext context) {
    final page = _pages[index];
    final settings = widget.settings;
    // LW-10.2: set current chapter for per-chapter CSS
    _currentChapterForCss = page.chapterIndex;
    final style = _getReaderStyle(settings);

    if (page.isCover) {
      return SafeArea(
        key: ValueKey('page-$index'),
        top: false,
        bottom: false,
        child: Directionality(
          textDirection: _readerTextDirection(
            settings.textDirection,
            context,
            bookTextDirection: _bookTextDirection(widget.metadata),
          ),
          child: _buildCoverPage(widget.metadata.coverUrl!, settings, style),
        ),
      );
    }

    final chapter = widget.loadedChapters[page.chapterIndex];
    final baseAlign = _resolveTextAlign(settings.textAlign);
    final isAsInBook = settings.textAlign == ReaderTextAlign.asInBook;
    final chapterHighlights = widget.chapterHighlights[page.chapterIndex];

    if (chapter == null) {
      return _readerLoadingPlaceholder(
        settings,
        page.chapterIndex,
        widget.metadata.chapterTitles,
        _getReaderStyle(settings),
      );
    }

    final ctx = _ctx(settings);
    final content = <Widget>[];

    if (page.showChapterTitle && chapter.title.isNotEmpty) {
      content.add(
        Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
          child: _readerHighlightedText(
            ctx,
            chapter.title,
            style.copyWith(fontSize: settings.fontSize * 1.4, fontWeight: FontWeight.bold),
            baseAlign,
          ),
        ),
      );
    }

    for (int i = page.blockStart; i < page.blockEnd && i < chapter.blocks.length; i++) {
      var block = chapter.blocks[i];
      if (widget.blockTransformers != null) {
        for (final t in widget.blockTransformers!) {
          final transformed = t(block);
          if (transformed == null) break;
          block = transformed;
        }
      }
      // Add spacing between consecutive blocks (except after first block)
      if (i > page.blockStart) {
        final prevBlock = chapter.blocks[i - 1];
        final needsExtraGap = _blockNeedsExtraGap(prevBlock.type, block.type);
        if (needsExtraGap) {
          content.add(SizedBox(height: settings.paragraphSpacing * 0.5));
        }
      }
      content.add(
        _buildReaderBlock(
          ctx,
          block,
          isAsInBook
              ? _resolveTextAlign(settings.textAlign, blockAlign: block.textAlign)
              : baseAlign,
          blockHighlights: chapterHighlights?.where((h) => h.blockIndex == i).toList(),
        ),
      );
    }

    return SafeArea(
      key: ValueKey('page-$index'),
      top: false,
      bottom: false,
      child: Directionality(
        textDirection: _readerTextDirection(
          settings.textDirection,
          context,
          bookTextDirection: _bookTextDirection(widget.metadata),
        ),
        child: Padding(
          padding: _effectiveMargin(settings, settings.mode),
          // Blocks are deliberately kept intact by the paginator. When one
          // exceeds a small viewport, retain the page boundary and make its
          // remainder reachable instead of overflowing the PageView.
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ),
      ),
    );
  }

  ReaderCtx _ctx(ReaderSettings settings) {
    final c =
        widget.customColors ??
        ReaderColors.forThemeWithContext(settings.theme, MediaQuery.platformBrightnessOf(context));
    return ReaderCtx(
      settings: settings,
      customColors: widget.customColors,
      highlightQuery: widget.highlightQuery,
      linkColor: c.link,
      brightness: MediaQuery.platformBrightnessOf(context),
      onLinkTap: widget.onLinkTap,
    );
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    return _readerTextStyle(
      settings,
      widget.customColors ??
          ReaderColors.forThemeWithContext(
            settings.theme,
            MediaQuery.platformBrightnessOf(context),
          ),
    );
  }

  Widget _buildTwoPage(int index, BuildContext context) {
    final leftIndex = index * 2;
    final rightIndex = index * 2 + 1;
    return Directionality(
      textDirection: _readerTextDirection(
        widget.settings.textDirection,
        context,
        bookTextDirection: _bookTextDirection(widget.metadata),
      ),
      child: Row(
        children: [
          Expanded(
            child: leftIndex < _pages.length
                ? _buildPaginatedPage(leftIndex, context)
                : const SizedBox.shrink(),
          ),
          Container(
            width: 1,
            color: _getReaderStyle(widget.settings).color?.withValues(alpha: 0.1),
          ),
          Expanded(
            child: rightIndex < _pages.length
                ? _buildPaginatedPage(rightIndex, context)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutMargin = _effectiveMargin(widget.settings, widget.settings.mode);
        // The page body applies this Padding at render time, so pagination
        // must measure the child constraints after the same inset.
        final availableHeight = constraints.maxHeight - layoutMargin.vertical;
        final contentWidth = constraints.maxWidth - layoutMargin.horizontal;
        final safeAvailableHeight = availableHeight > 1.0 ? availableHeight : 1.0;
        final safeContentWidth = contentWidth > 1.0 ? contentWidth : 1.0;
        // HG-6.1: check layout cache
        final s = widget.settings;
        final useTwoPageLayout = s.twoPageEnabled && context.canUseTwoPageMode;
        // Each spread page is rendered in half the available width, after the
        // divider is reserved, so paginate using that actual child width.
        final pageContentWidth = useTwoPageLayout
            ? ((safeContentWidth - 1) / 2).clamp(1.0, safeContentWidth)
            : safeContentWidth;
        final key =
            '${s.fontSize}_${s.lineHeight}_${layoutMargin.top}_${layoutMargin.bottom}_'
            '${layoutMargin.left}_${layoutMargin.right}_${s.paragraphSpacing}_'
            '${s.letterSpacing}_${s.paragraphFirstLineIndent}_${s.font}_'
            '${s.hyphenation}_${s.textAlign.name}_${s.paragraphIndentMode.name}_'
            '${s.ignoreBookIndent}_${s.wordSpacing}_${s.fontWeightDelta}_${s.textDirection.name}_'
            '${s.customCss}_${s.showImages}_${s.imageWidth}_${useTwoPageLayout}_'
            '${safeAvailableHeight.toStringAsFixed(1)}_${pageContentWidth.toStringAsFixed(1)}_'
            '${widget.loadedChapters.length}';
        if (key == _cacheKey && _cachedPages.isNotEmpty) {
          _pages = _cachedPages;
        } else {
          _pages = _paginateContent(safeAvailableHeight, pageContentWidth);
          _cacheKey = key;
          _cachedPages = _pages;
        }
        final pageCount = _pages.length;
        if (pageCount == 0) {
          return const SizedBox.shrink();
        }

        final effectivePageCount = useTwoPageLayout ? ((pageCount + 1) ~/ 2) : pageCount;

        if (!_didRestoreInitialPage && widget.initialPage > 0) {
          final hasCover = widget.metadata.coverUrl != null && widget.metadata.coverUrl!.isNotEmpty;
          final pageOffset = hasCover ? 1 : 0;
          final targetPage =
              (useTwoPageLayout
                      ? (widget.initialPage + pageOffset) ~/ 2
                      : widget.initialPage + pageOffset)
                  .clamp(0, effectivePageCount - 1);
          _didRestoreInitialPage = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_disposed || !_pageController.hasClients) return;
            unawaited(
              _pageController.animateToPage(
                targetPage,
                duration: Duration.zero,
                curve: Curves.easeInOut,
              ),
            );
          });
        }

        Widget itemBuilder(BuildContext context, int index) {
          if (useTwoPageLayout) {
            return _buildTwoPage(index, context);
          }
          return index < _pages.length
              ? _buildPaginatedPage(index, context)
              : const SizedBox.shrink();
        }

        final anim = widget.settings.pageTurnAnimation;
        final useSwitcher =
            anim == PageTurnAnimation.fade ||
            anim == PageTurnAnimation.curl ||
            anim == PageTurnAnimation.stack;
        final switcherDuration = anim == PageTurnAnimation.curl ? 350 : 250;
        final physics = anim == PageTurnAnimation.none
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics();

        final Widget pageContent = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTap,
          child: PageView.builder(
            controller: _pageController,
            physics: physics,
            padEnds: false,
            itemCount: effectivePageCount,
            onPageChanged: (index) {
              final pageIndex = useTwoPageLayout ? index * 2 : index;
              if (_pages.isNotEmpty && pageIndex < _pages.length) {
                widget.onPageChanged?.call(_pages[pageIndex].chapterIndex);
              }
            },
            itemBuilder: useSwitcher
                ? (context, index) {
                    final child = itemBuilder(context, index);
                    // LW-2.1: 3D page curl with shadow gradient
                    if (anim == PageTurnAnimation.curl) {
                      return AnimatedSwitcher(
                        duration: Duration(milliseconds: switcherDuration),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) {
                              final t = animation.value;
                              final rotation = (1 - t) * 0.4;
                              final opacity = t.clamp(0.0, 1.0);
                              // Shadow peaks mid-animation
                              final shadowAlpha = (0.3 * (t * (1 - t)) * 4).clamp(0.0, 0.3);
                              return Stack(
                                children: [
                                  Transform(
                                    alignment: Alignment.centerRight,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.002)
                                      ..rotateY(-rotation),
                                    child: Opacity(
                                      opacity: opacity,
                                      child: child,
                                    ),
                                  ),
                                  // Shadow gradient on curling page leading edge
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            end: Alignment.center,
                                            colors: [
                                              Colors.black.withValues(alpha: shadowAlpha),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: child,
                      );
                    }
                    // LW-2.2: Stack animation — new page slides over from right with shadow
                    if (anim == PageTurnAnimation.stack) {
                      return AnimatedSwitcher(
                        duration: Duration(milliseconds: switcherDuration),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) {
                              final t = animation.value;
                              return Stack(
                                children: [
                                  child!,
                                  // Shadow gradient on leading edge of incoming page
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            end: Alignment.center,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.25 * (1 - t)),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: child,
                      );
                    }
                    return AnimatedSwitcher(
                      duration: Duration(milliseconds: switcherDuration),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: child,
                    );
                  }
                : itemBuilder,
          ),
        );

        if (widget.settings.perceptionExpander || widget.settings.horizontalLimiter) {
          return Stack(
            children: [
              pageContent,
              ..._readerOverlays(
                widget.settings,
                _getReaderStyle(widget.settings).color ?? Colors.black,
                MediaQuery.sizeOf(context).height,
              ),
            ],
          );
        }
        return pageContent;
      },
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior({this.inertia = ScrollInertia.medium});
  final ScrollInertia inertia;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (inertia == ScrollInertia.none) {
      return const ClampingScrollPhysics();
    }
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux => const ClampingScrollPhysics(),
      TargetPlatform.iOS => const BouncingScrollPhysics(),
    };
  }
}

/// LW-8.1: Fixed-layout EPUB — each spine item is a full-screen page.
/// ponytail: image pages full-screen, text pages centered. No absolute
/// positioning, no SVG — add when test corpus includes those features.
class _FixedLayoutBody extends StatelessWidget {
  const _FixedLayoutBody({
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.initialPage,
    this.onTap,
    this.onPageChanged,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final int initialPage;
  final void Function(TapUpDetails)? onTap;
  final void Function(int page)? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageView.builder(
      onPageChanged: onPageChanged,
      itemCount: metadata.chapterCount,
      itemBuilder: (_, index) {
        final chapter = loadedChapters[index];
        if (chapter == null) return const SizedBox.shrink();

        final imgBlocks = chapter.blocks
            .where((b) => b.type == BlockType.image && b.imageUrl != null)
            .toList();
        if (imgBlocks.isNotEmpty) {
          return _imagePage(imgBlocks.first.imageUrl!, context);
        }
        return _textPage(chapter, theme, context);
      },
    );
  }

  Widget _imagePage(String url, BuildContext context) {
    return GestureDetector(
      onTapUp: onTap,
      child: InteractiveViewer(
        child: Center(
          child: _loadImage(url, BoxFit.contain),
        ),
      ),
    );
  }

  Widget _textPage(ReaderChapter chapter, ThemeData theme, BuildContext context) {
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    return GestureDetector(
      onTapUp: onTap,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chapter.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ...chapter.blocks.where((b) => b.text.isNotEmpty).map((b) {
                  final style = b.type == BlockType.heading
                      ? TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        )
                      : TextStyle(fontSize: 14, color: textColor);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(b.text, style: style),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadImage(String url, BoxFit fit) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'data') {
      final separator = url.indexOf(',');
      if (separator > 0 && url.substring(0, separator).toLowerCase().contains(';base64')) {
        try {
          return Image.memory(
            base64Decode(url.substring(separator + 1)),
            fit: fit,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.white,
            ),
          );
        } on FormatException {
          return const Icon(Icons.broken_image, size: 64, color: Colors.white);
        }
      }
    }
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File(uri.path),
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64, color: Colors.white),
      );
    }
    if (uri == null || !uri.isAbsolute) {
      return Image.file(
        File(url),
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64, color: Colors.white),
      );
    }
    return const Icon(Icons.broken_image, size: 64, color: Colors.white);
  }
}

// LW-3.1/3.2: RSVP speed-reading mode — one word at a time
class _RsvpModeBody extends StatefulWidget {
  const _RsvpModeBody({
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.initialChapterIndex,
    this.customColors,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final int initialChapterIndex;
  final ReaderColors? customColors;

  @override
  State<_RsvpModeBody> createState() => _RsvpModeBodyState();
}

class _RsvpModeBodyState extends State<_RsvpModeBody> {
  late List<String> _words;
  int _wordIndex = 0;
  bool _playing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _words = _buildWordList();
  }

  @override
  void didUpdateWidget(_RsvpModeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadedChapters != widget.loadedChapters) {
      final newIndex = _wordIndex;
      _words = _buildWordList();
      if (newIndex >= _words.length) _wordIndex = 0;
    }
  }

  List<String> _buildWordList() {
    final words = <String>[];
    for (var ch = 0; ch < widget.metadata.chapterCount; ch++) {
      final chapter = widget.loadedChapters[ch];
      if (chapter == null) continue;
      for (final block in chapter.blocks) {
        if (block.text.isNotEmpty) {
          words.addAll(block.text.split(RegExp(r'\s+')));
        }
      }
    }
    return words;
  }

  void _togglePlay() {
    if (_words.isEmpty) return;
    if (_playing) {
      _timer?.cancel();
      _timer = null;
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final interval = Duration(milliseconds: (60000 / widget.settings.rsvpWpm).round());
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      if (_wordIndex < _words.length - 1) {
        setState(() => _wordIndex++);
      } else {
        _timer?.cancel();
        _timer = null;
        setState(() => _playing = false);
      }
    });
  }

  void _skip(int delta) {
    if (_words.isEmpty) return;
    _timer?.cancel();
    setState(() {
      _wordIndex = (_wordIndex + delta).clamp(0, _words.length - 1);
      if (_playing) _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final colors =
        widget.customColors ??
        ReaderColors.forThemeWithContext(s.theme, MediaQuery.platformBrightnessOf(context));
    final word = _words.isEmpty ? '' : _words[_wordIndex];
    final progress = _words.isEmpty ? 0.0 : (_wordIndex + 1) / _words.length;
    final displayedWordIndex = _words.isEmpty ? 0 : _wordIndex + 1;

    return ColoredBox(
      color: colors.scaffold,
      child: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: colors.text.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(colors.text.withValues(alpha: 0.4)),
            ),
            // Word display
            Expanded(
              child: GestureDetector(
                onTap: _togglePlay,
                onLongPress: () => _skip(-10),
                onHorizontalDragEnd: (_) => _skip(0),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: s.fontSize * 1.8,
                        height: 1.3,
                        color: colors.text,
                        fontFamily: s.font.fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            // Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: colors.text.withValues(alpha: 0.6),
                    onPressed: () => _skip(-10),
                  ),
                  const SizedBox(width: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.text.withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 32),
                      color: colors.text,
                      onPressed: _togglePlay,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: colors.text.withValues(alpha: 0.6),
                    onPressed: () => _skip(10),
                  ),
                ],
              ),
            ),
            // WPM label
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${s.rsvpWpm} сл/мин  ·  $displayedWordIndex/${_words.length}',
                style: TextStyle(
                  color: colors.text.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
