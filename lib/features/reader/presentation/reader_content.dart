import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/adaptive_context.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'highlighted_text.dart';

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

TextAlign _resolveTextAlign(ReaderTextAlign a) {
  return switch (a) {
    ReaderTextAlign.left => TextAlign.left,
    ReaderTextAlign.justify => TextAlign.justify,
    ReaderTextAlign.center => TextAlign.center,
    ReaderTextAlign.right => TextAlign.right,
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

TextStyle _readerTextStyle(ReaderSettings s, ReaderColors colors) {
  final fontFamily = s.font == ReaderFont.inter ? 'Inter' : 'Literata';
  final fw = (s.fontWeightDelta > 0.33)
      ? FontWeight.w600
      : (s.fontWeightDelta > 0)
      ? FontWeight.w500
      : (s.fontWeightDelta < -0.33)
      ? FontWeight.w300
      : FontWeight.w400;
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: s.fontSize,
    height: s.lineHeight,
    color: colors.text,
    letterSpacing: s.letterSpacing,
    fontWeight: fw,
  );
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
          block.textAlign ?? TextAlign.left,
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
          block.textAlign ?? TextAlign.right,
        ),
      );
    case BlockType.poem:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing * 2),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic),
          TextAlign.center,
        ),
      );
    case BlockType.cite:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
        padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: (style.color ?? Colors.black).withValues(alpha: 0.3), width: 3),
          ),
        ),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontStyle: FontStyle.italic),
          TextAlign.left,
        ),
      );
    case BlockType.textAuthor:
      return Padding(
        padding: EdgeInsets.only(top: s.paragraphSpacing, left: s.margin),
        child: _readerHighlightedText(
          ctx,
          '— ${block.text}',
          style.copyWith(
            fontSize: s.fontSize * 0.9,
            fontStyle: FontStyle.italic,
            color: (style.color ?? Colors.black).withValues(alpha: 0.6),
          ),
          TextAlign.right,
          richSpans: block.richSpans,
        ),
      );
    case BlockType.quote:
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: (style.color ?? Colors.black).withValues(alpha: 0.3), width: 3),
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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing),
          child: Align(
            alignment: switch (s.imageAlignment) {
              ImageAlignment.start => Alignment.centerLeft,
              ImageAlignment.center => Alignment.center,
              ImageAlignment.end => Alignment.centerRight,
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600 * s.imageWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s.imageCornerRadius),
                child: _readerImageWidget(block.imageUrl!, style.color, s),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    case BlockType.footnote:
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.paragraphSpacing / 2),
        child: _readerHighlightedText(
          ctx,
          block.text,
          style.copyWith(fontSize: s.fontSize * 0.85),
          textAlign,
        ),
      );
    case BlockType.table:
      return _readerTableBlock(block, s, style);
    case BlockType.list:
      return _readerListBlock(ctx, block, textAlign);
    case BlockType.paragraph:
      final indentValue = (block.textIndent != null && block.textIndent! > 0)
          ? block.textIndent!
          : s.paragraphFirstLineIndent;
      return Padding(
        padding: EdgeInsets.only(bottom: s.paragraphSpacing),
        child: blockHighlights != null && blockHighlights.isNotEmpty
            ? Padding(
                padding: EdgeInsets.only(left: indentValue),
                child: HighlightedText(
                  text: block.text,
                  style: style,
                  textAlign: block.textAlign ?? textAlign,
                  highlights: blockHighlights,
                ),
              )
            : _readerHighlightedText(
                ctx,
                block.text,
                style,
                block.textAlign ?? textAlign,
                richSpans: block.richSpans,
                firstLineIndent: indentValue,
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
}) {
  final query = ctx.highlightQuery?.trim();
  if (query == null || query.isEmpty) {
    if (richSpans != null && richSpans.isNotEmpty) {
      final spans = _readerRichTextSpans(
        richSpans,
        style,
        ctx.linkColor,
        onLinkTap: ctx.onLinkTap,
      );
      if (firstLineIndent > 0) {
        spans.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndent)));
      }
      return Text.rich(TextSpan(children: spans), textAlign: textAlign);
    }
    if (ctx.settings.bionicReading) {
      final spans = _bionicReadingSpans(text, style);
      if (firstLineIndent > 0) {
        spans.insert(0, WidgetSpan(child: SizedBox(width: firstLineIndent)));
      }
      return Text.rich(TextSpan(children: spans), textAlign: textAlign);
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
      );
    }
    return Text(text, style: style, textAlign: textAlign);
  }
  return Text.rich(
    TextSpan(children: _readerHighlightedSpans(text, style, query)),
    textAlign: textAlign,
  );
}

List<InlineSpan> _readerRichTextSpans(
  List<RichSpan> richSpans,
  TextStyle baseStyle,
  Color linkColor, {
  ValueChanged<String>? onLinkTap,
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
    if (span.href != null) {
      spanStyle = spanStyle.copyWith(color: linkColor, decoration: TextDecoration.underline);
    }
    if (span.superscript) {
      final supFontSize = baseStyle.fontSize != null ? baseStyle.fontSize! * 0.7 : 12.0;
      final supStyle = spanStyle.copyWith(fontSize: supFontSize);
      if (span.href != null && onLinkTap != null) {
        final href = span.href!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(0, -(baseStyle.fontSize ?? 16) * 0.3),
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
              offset: Offset(0, -(baseStyle.fontSize ?? 16) * 0.3),
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

List<InlineSpan> _readerHighlightedSpans(String text, TextStyle style, String query) {
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
        style: style.copyWith(backgroundColor: const Color(0x66FFEB3B)),
      ),
    );
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  return spans;
}

Widget _readerImageWidget(String imageUrl, Color? errorColor, ReaderSettings settings) {
  final colorFilter = _imageColorFilter(settings);
  final uri = Uri.tryParse(imageUrl);
  final isDataUri = uri != null && uri.scheme == 'data';
  final isFileUri = uri != null && uri.scheme == 'file';
  final isPlainPath = uri == null || !uri.isAbsolute;

  Widget wrap(Widget img) =>
      colorFilter != null ? ColorFiltered(colorFilter: colorFilter, child: img) : img;

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
    return wrap(
      InteractiveViewer(
        maxScale: 4.0,
        child: Image.file(
          File(isFileUri ? uri.path : imageUrl),
          fit: BoxFit.contain,
          errorBuilder: (ctx, e, s) => Icon(Icons.broken_image, size: 64, color: errorColor),
        ),
      ),
    );
  }
  return Icon(Icons.broken_image, size: 64, color: errorColor);
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
          padding: const EdgeInsets.only(left: 24, bottom: 4),
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

TextDirection _readerTextDirection(ReaderTextDirection td, BuildContext context) {
  return switch (td) {
    ReaderTextDirection.ltr => TextDirection.ltr,
    ReaderTextDirection.rtl => TextDirection.rtl,
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

    final effectiveMargin = _effectiveMargin(settings, settings.mode);
    final textDirection = _readerTextDirection(settings.textDirection, context);
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
              ScrollConfiguration(
                behavior: const _SmoothScrollBehavior(),
                child: Scrollbar(
                  controller: widget.scrollController,
                  thumbVisibility: true,
                  thickness: 3,
                  radius: const Radius.circular(1.5),
                  child: ListView.builder(
                    controller: widget.scrollController,
                    padding: effectiveMargin,
                    itemCount: itemCount,
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
    final textAlign = _resolveTextAlign(settings.textAlign);
    final ctx = _ctx(settings);
    final chapterHighlights = widget.chapterHighlights[chapterIndex];

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
              textAlign,
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ...chapter.blocks.asMap().entries.map((entry) {
          var block = entry.value;
          if (widget.blockTransformers != null) {
            for (final t in widget.blockTransformers!) {
              final transformed = t(block);
              if (transformed == null) return const SizedBox.shrink();
              block = transformed;
            }
          }
          return _buildReaderBlock(
            ctx,
            block,
            textAlign,
            blockHighlights: chapterHighlights
                ?.where((TextHighlight h) => h.blockIndex == entry.key)
                .toList(),
          );
        }),
      ],
    );
  }

  ReaderCtx _ctx(ReaderSettings settings) {
    return ReaderCtx(
      settings: settings,
      customColors: widget.customColors,
      highlightQuery: widget.highlightQuery,
      linkColor: Theme.of(context).colorScheme.primary,
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _PaginatedContentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPage != oldWidget.initialPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !_pageController.hasClients) return;
        final pageCount = _pages.length;
        if (pageCount == 0) return;
        final targetPage = widget.initialPage.clamp(0, pageCount - 1);
        unawaited(
          _pageController.animateToPage(
            targetPage,
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

  List<_PageContent> _paginateContent(double availableHeight, double contentWidth) {
    final settings = widget.settings;
    final style = _getReaderStyle(settings);
    final pages = <_PageContent>[];
    const minFillRatio = 0.3;

    final hasCover = widget.metadata.coverUrl != null && widget.metadata.coverUrl!.isNotEmpty;
    if (hasCover) {
      pages.add(const _PageContent(chapterIndex: 0, blockStart: 0, blockEnd: 0, isCover: true));
    }

    for (int chIdx = 0; chIdx < widget.metadata.chapterCount; chIdx++) {
      final chapter = widget.loadedChapters[chIdx];
      if (chapter == null || chapter.blocks.isEmpty) {
        pages.add(
          _PageContent(chapterIndex: chIdx, blockStart: 0, blockEnd: 0, showChapterTitle: true),
        );
        continue;
      }

      final titleHeight = chapter.title.isNotEmpty
          ? settings.fontSize * 1.4 * settings.lineHeight + settings.paragraphSpacing * 2
          : 0.0;
      var currentHeight = titleHeight;
      var pageStart = 0;

      for (int i = 0; i < chapter.blocks.length; i++) {
        final block = chapter.blocks[i];
        final blockHeight = _estimateBlockHeight(block, settings, style, contentWidth);

        if (currentHeight + blockHeight > availableHeight && i > pageStart) {
          // Don't break if current page is mostly empty (< 30% filled)
          if (currentHeight > availableHeight * minFillRatio) {
            pages.add(
              _PageContent(
                chapterIndex: chIdx,
                blockStart: pageStart,
                blockEnd: i,
                showChapterTitle: pages.isEmpty || pages.last.chapterIndex != chIdx,
              ),
            );
            pageStart = i;
            currentHeight = blockHeight;
          } else {
            // Page is too empty — let block overflow, accept slight overfill
            currentHeight += blockHeight;
          }
        } else {
          currentHeight += blockHeight;
        }
      }

      // Final page: if it would be very short (< 25%), merge with previous page
      if (pageStart > 0 &&
          pages.isNotEmpty &&
          pages.last.chapterIndex == chIdx &&
          currentHeight < availableHeight * 0.25) {
        // Extend previous page to include remaining blocks
        final lastPage = pages.last;
        pages[pages.length - 1] = _PageContent(
          chapterIndex: lastPage.chapterIndex,
          blockStart: lastPage.blockStart,
          blockEnd: chapter.blocks.length,
          showChapterTitle: lastPage.showChapterTitle,
        );
      } else {
        pages.add(
          _PageContent(
            chapterIndex: chIdx,
            blockStart: pageStart,
            blockEnd: chapter.blocks.length,
            showChapterTitle: pages.isEmpty || pages.last.chapterIndex != chIdx,
          ),
        );
      }
    }
    return pages;
  }

  double _estimateBlockHeight(
    ReaderBlock block,
    ReaderSettings settings,
    TextStyle style,
    double width,
  ) {
    final ps = settings.paragraphSpacing;
    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 2;
        final scale = _headingScale(level);
        final spacing = _headingSpacing(ps, level);
        return _measureTextHeight(
              block.text,
              settings.fontSize * scale,
              settings.lineHeight,
              width,
            ) +
            spacing +
            ps;
      case BlockType.subtitle:
        return _measureTextHeight(block.text, settings.fontSize * 1.1, settings.lineHeight, width) +
            ps * 3;
      case BlockType.epigraph:
        return _measureTextHeight(
              block.text,
              settings.fontSize * 0.95,
              settings.lineHeight,
              width - settings.margin,
            ) +
            ps * 2 +
            24;
      case BlockType.poem:
        return _measureTextHeight(block.text, settings.fontSize, settings.lineHeight, width - 48) +
            ps * 4;
      case BlockType.cite:
        return _measureTextHeight(block.text, settings.fontSize, settings.lineHeight, width - 40) +
            ps +
            16;
      case BlockType.textAuthor:
        return settings.fontSize * 0.9 * settings.lineHeight + ps;
      case BlockType.quote:
        return _measureTextHeight(block.text, settings.fontSize, settings.lineHeight, width - 32) +
            ps +
            16;
      case BlockType.separator:
        return ps * 4;
      case BlockType.image:
        final imgWidth = (width * settings.imageWidth).clamp(50.0, 600.0 * settings.imageWidth);
        return (imgWidth / 1.4).clamp(80.0, 400.0) + ps;
      case BlockType.footnote:
        return _measureTextHeight(
              block.text,
              settings.fontSize * 0.85,
              settings.lineHeight,
              width,
            ) +
            ps;
      case BlockType.table:
        final rows = block.tableRows?.length ?? 0;
        return (rows * settings.fontSize * settings.lineHeight * 1.3) + ps * 2 + 16;
      case BlockType.list:
        var totalHeight = ps + 8.0;
        for (final item in block.listItems ?? <ReaderBlock>[]) {
          totalHeight +=
              _measureTextHeight(item.text, settings.fontSize, settings.lineHeight, width - 32) + 4;
        }
        return totalHeight;
      case BlockType.paragraph:
        final indent = (block.textIndent ?? settings.paragraphFirstLineIndent);
        return _measureTextHeight(
              block.text,
              settings.fontSize,
              settings.lineHeight,
              width - indent,
            ) +
            ps;
    }
  }

  double _measureTextHeight(String text, double fontSize, double lineHeight, double maxWidth) {
    if (text.isEmpty) return fontSize * lineHeight;
    final s = widget.settings;
    final colors =
        widget.customColors ??
        ReaderColors.forThemeWithContext(s.theme, MediaQuery.platformBrightnessOf(context));
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _readerTextStyle(s, colors).copyWith(fontSize: fontSize, height: lineHeight),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Widget _buildPaginatedPage(int index, BuildContext context) {
    final page = _pages[index];
    final settings = widget.settings;
    final style = _getReaderStyle(settings);

    if (page.isCover) {
      return SafeArea(
        key: ValueKey('page-$index'),
        top: false,
        bottom: false,
        child: Directionality(
          textDirection: _readerTextDirection(settings.textDirection, context),
          child: _buildCoverPage(widget.metadata.coverUrl!, settings, style),
        ),
      );
    }

    final chapter = widget.loadedChapters[page.chapterIndex];
    final textAlign = _resolveTextAlign(settings.textAlign);
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
            textAlign,
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
          textAlign,
          blockHighlights: chapterHighlights?.where((h) => h.blockIndex == i).toList(),
        ),
      );
    }

    return SafeArea(
      key: ValueKey('page-$index'),
      top: false,
      bottom: false,
      child: Directionality(
        textDirection: _readerTextDirection(settings.textDirection, context),
        child: Padding(
          padding: _effectiveMargin(settings, settings.mode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ),
    );
  }

  ReaderCtx _ctx(ReaderSettings settings) {
    return ReaderCtx(
      settings: settings,
      customColors: widget.customColors,
      highlightQuery: widget.highlightQuery,
      linkColor: Theme.of(context).colorScheme.primary,
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
      textDirection: _readerTextDirection(widget.settings.textDirection, context),
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
        final availableHeight = constraints.maxHeight;
        final contentWidth = constraints.maxWidth - widget.settings.margin * 2;
        _pages = _paginateContent(availableHeight, contentWidth);
        final pageCount = _pages.length;
        if (pageCount == 0) {
          return const SizedBox.shrink();
        }

        final useTwoPageLayout = widget.settings.twoPageEnabled && context.canUseTwoPageMode;
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
        final useSwitcher = anim == PageTurnAnimation.fade || anim == PageTurnAnimation.curl;
        final switcherDuration = anim == PageTurnAnimation.curl ? 400 : 200;
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
              if (_pages.isNotEmpty && index < _pages.length) {
                widget.onPageChanged?.call(_pages[index].chapterIndex);
              }
            },
            itemBuilder: useSwitcher
                ? (context, index) => AnimatedSwitcher(
                    duration: Duration(milliseconds: switcherDuration),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: itemBuilder(context, index),
                  )
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
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = Theme.of(context).platform;
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
