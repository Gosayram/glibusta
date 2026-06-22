import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/adaptive_context.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'highlighted_text.dart';

List<InlineSpan> _bionicReadingSpans(
  String text,
  TextStyle style, [
  FontWeight thickness = FontWeight.w700,
]) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == ' ' || ch == '\n' || ch == '\t') {
      if (buffer.isNotEmpty) {
        _appendBionicWord(spans, buffer.toString(), style, thickness);
        buffer.clear();
      }
      spans.add(TextSpan(text: ch, style: style));
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) {
    _appendBionicWord(spans, buffer.toString(), style, thickness);
  }
  return spans;
}

void _appendBionicWord(
  List<InlineSpan> spans,
  String word,
  TextStyle style,
  FontWeight thickness,
) {
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
      style: style.copyWith(fontWeight: thickness),
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
    this.ttsHighlightIndex,
    this.chapterHighlights = const <int, List<TextHighlight>>{},
    this.blockTransformers,
    this.customColors,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final ScrollController scrollController;
  final GestureTapUpCallback onTap;
  final double initialProgress;
  final int initialPage;
  final String? highlightQuery;
  final int? ttsHighlightIndex;
  final Map<int, List<TextHighlight>> chapterHighlights;
  final List<BlockTransformer>? blockTransformers;
  final ReaderColors? customColors;

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
    final metadata = widget.metadata;
    final loadedChapters = widget.loadedChapters;
    final settings = widget.settings;
    final scrollController = widget.scrollController;
    final onTap = widget.onTap;
    final initialProgress = widget.initialProgress;
    final initialPage = widget.initialPage;
    final highlightQuery = widget.highlightQuery;

    final effectiveMode = settings.mode == ReaderMode.auto ? ReaderMode.paginated : settings.mode;
    if (effectiveMode == ReaderMode.paginated || effectiveMode == ReaderMode.twoPage) {
      return _PaginatedContentBody(
        metadata: metadata,
        loadedChapters: loadedChapters,
        settings: settings,
        onTap: onTap,
        initialPage: initialPage,
        highlightQuery: highlightQuery,
        ttsHighlightIndex: widget.ttsHighlightIndex,
        chapterHighlights: widget.chapterHighlights,
        blockTransformers: widget.blockTransformers,
        customColors: widget.customColors,
      );
    }

    final isFocus = effectiveMode == ReaderMode.focus || effectiveMode == ReaderMode.fullscreen;
    final effectiveMargin = isFocus
        ? EdgeInsets.symmetric(
            horizontal: settings.margin * 1.5,
            vertical: settings.margin,
          )
        : EdgeInsets.all(settings.margin);
    final textDirection = _effectiveTextDirection(context, settings);

    if (!_didScrollToProgress && initialProgress > 0) {
      _didScrollToProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        final maxScroll = scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          unawaited(
            scrollController.animateTo(
              (initialProgress * maxScroll).clamp(0.0, maxScroll),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          );
        }
      });
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: onTap,
        child: Directionality(
          textDirection: textDirection,
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: const _SmoothScrollBehavior(),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  thickness: 3,
                  radius: const Radius.circular(1.5),
                  child: ListView.builder(
                    controller: scrollController,
                    padding: effectiveMargin,
                    itemCount: metadata.chapterCount,
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) {
                      final chapter = loadedChapters[index];
                      final isLast = index == metadata.chapterCount - 1;
                      final nextTitle = index + 1 < metadata.chapterTitles.length
                          ? metadata.chapterTitles[index + 1]
                          : '';
                      return Column(
                        key: ValueKey('chapter-$index'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (chapter != null)
                            _buildChapterContent(chapter, settings, index)
                          else
                            _buildLoadingPlaceholder(settings, index),
                          if (!isLast && chapter != null && loadedChapters[index + 1] != null)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: settings.paragraphSpacing * 3,
                              ),
                              child: Center(
                                child: Text(
                                  '— ${nextTitle.isNotEmpty ? nextTitle : "Глава ${index + 2}"} —',
                                  style: _getReaderStyle(settings).copyWith(
                                    color: _getReaderStyle(settings).color?.withValues(alpha: 0.4),
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
              if (settings.perceptionExpander) ...[
                Positioned(
                  left: settings.margin - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: _getReaderStyle(settings).color?.withValues(alpha: 0.15),
                  ),
                ),
                Positioned(
                  right: settings.margin - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: _getReaderStyle(settings).color?.withValues(alpha: 0.15),
                  ),
                ),
              ],
              if (settings.horizontalLimiter) ...[
                // Top dimming zone
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _limiterTopOffset(settings),
                  child: ColoredBox(
                    color:
                        _getReaderStyle(
                          settings,
                        ).color?.withValues(alpha: settings.horizontalLimiterDimming) ??
                        Colors.black.withValues(alpha: settings.horizontalLimiterDimming),
                  ),
                ),
                // Bottom dimming zone
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _limiterBottomOffset(settings),
                  child: ColoredBox(
                    color:
                        _getReaderStyle(
                          settings,
                        ).color?.withValues(alpha: settings.horizontalLimiterDimming) ??
                        Colors.black.withValues(alpha: settings.horizontalLimiterDimming),
                  ),
                ),
                // Top ruler line
                if (settings.horizontalLimiterLines) ...[
                  Positioned(
                    left: settings.margin,
                    right: settings.margin,
                    top: _limiterTopOffset(settings),
                    child: Container(
                      height: 1,
                      color:
                          _getReaderStyle(settings).color?.withValues(alpha: 0.2) ??
                          Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    left: settings.margin,
                    right: settings.margin,
                    bottom: _limiterBottomOffset(settings),
                    child: Container(
                      height: 1,
                      color:
                          _getReaderStyle(settings).color?.withValues(alpha: 0.2) ??
                          Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ReaderSettings settings, int index) {
    final title = index < widget.metadata.chapterTitles.length
        ? widget.metadata.chapterTitles[index]
        : 'Глава ${index + 1}';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: settings.paragraphSpacing * 3),
          Center(
            child: SizedBox(
              width: settings.fontSize * 1.5,
              height: settings.fontSize * 1.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _getReaderStyle(settings).color?.withValues(alpha: 0.3),
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
                  color: _getReaderStyle(settings).color?.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContent(ReaderChapter chapter, ReaderSettings settings, int chapterIndex) {
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    final chapterHighlights = widget.chapterHighlights[chapterIndex];

    final header = chapter.title.isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
            child: _buildHighlightedText(
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
          return _buildBlock(
            block,
            settings,
            textAlign,
            blockHighlights: chapterHighlights
                ?.where((TextHighlight h) => h.blockIndex == entry.key)
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _buildBlock(
    ReaderBlock block,
    ReaderSettings settings,
    TextAlign textAlign, {
    List<TextHighlight>? blockHighlights,
  }) {
    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 2;
        final scale = switch (level) {
          1 => 1.6,
          2 => 1.4,
          3 => 1.2,
          _ => 1.1,
        };
        final spacing = switch (level) {
          1 => settings.paragraphSpacing * 3,
          2 => settings.paragraphSpacing * 2,
          _ => settings.paragraphSpacing * 1.5,
        };
        return Padding(
          padding: EdgeInsets.only(top: spacing, bottom: settings.paragraphSpacing),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * scale,
              fontWeight: level <= 2 ? FontWeight.bold : FontWeight.w600,
            ),
            block.textAlign ?? textAlign,
          ),
        );
      case BlockType.subtitle:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.1,
              fontStyle: FontStyle.italic,
            ),
            block.textAlign ?? TextAlign.center,
          ),
        );
      case BlockType.epigraph:
        return Container(
          margin: EdgeInsets.symmetric(
            vertical: settings.paragraphSpacing * 2,
            horizontal: settings.margin * 0.5,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHighlightedText(
                block.text,
                _getReaderStyle(settings).copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: settings.fontSize * 0.95,
                ),
                TextAlign.right,
              ),
            ],
          ),
        );
      case BlockType.poem:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(
              fontStyle: FontStyle.italic,
            ),
            TextAlign.center,
          ),
        );
      case BlockType.cite:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: (_getReaderStyle(settings).color ?? Colors.black).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(fontStyle: FontStyle.italic),
            TextAlign.left,
          ),
        );
      case BlockType.textAuthor:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing,
            left: settings.margin,
          ),
          child: Text(
            '— ${block.text}',
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 0.9,
              fontStyle: FontStyle.italic,
              color: (_getReaderStyle(settings).color ?? Colors.black).withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.right,
          ),
        );
      case BlockType.quote:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: (_getReaderStyle(settings).color ?? Colors.black).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(fontStyle: FontStyle.italic),
            textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: _getReaderStyle(settings))),
        );
      case BlockType.image:
        if (!settings.showImages) return const SizedBox.shrink();
        if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Align(
              alignment: switch (settings.imageAlignment) {
                ImageAlignment.start => Alignment.centerLeft,
                ImageAlignment.center => Alignment.center,
                ImageAlignment.end => Alignment.centerRight,
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600 * settings.imageWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(settings.imageCornerRadius),
                  child: _buildImageWidget(
                    block.imageUrl!,
                    _getReaderStyle(settings).color,
                    settings,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case BlockType.footnote:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing / 2),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 0.85,
            ),
            textAlign,
          ),
        );
      case BlockType.table:
        return _buildTable(block, settings);
      case BlockType.list:
        return _buildList(block, settings, textAlign);
      case BlockType.paragraph:
        final indent = (block.textIndent != null && block.textIndent! > 0)
            ? EdgeInsets.only(left: block.textIndent!)
            : (settings.paragraphFirstLineIndent > 0
                  ? EdgeInsets.only(left: settings.paragraphFirstLineIndent)
                  : EdgeInsets.zero);
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Padding(
            padding: indent,
            child: blockHighlights != null && blockHighlights.isNotEmpty
                ? HighlightedText(
                    text: block.text,
                    style: _getReaderStyle(settings),
                    textAlign: block.textAlign ?? textAlign,
                    highlights: blockHighlights,
                  )
                : _buildHighlightedText(
                    block.text,
                    _getReaderStyle(settings),
                    block.textAlign ?? textAlign,
                    richSpans: block.richSpans,
                  ),
          ),
        );
    }
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle style,
    TextAlign textAlign, {
    List<RichSpan>? richSpans,
  }) {
    final query = widget.highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      if (richSpans != null && richSpans.isNotEmpty) {
        return Text.rich(
          TextSpan(children: _buildRichTextSpans(richSpans, style)),
          textAlign: textAlign,
        );
      }
      if (widget.settings.bionicReading) {
        return Text.rich(
          TextSpan(children: _bionicReadingSpans(text, style)),
          textAlign: textAlign,
        );
      }
      return Text(text, style: style, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(children: _buildHighlightedSpans(text, style, query)),
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildRichTextSpans(List<RichSpan> richSpans, TextStyle baseStyle) {
    final linkColor = Theme.of(context).colorScheme.primary;
    final spans = <InlineSpan>[];
    for (final span in richSpans) {
      if (span.lineBreak) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      var spanStyle = baseStyle;
      if (span.bold) spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      if (span.italic) spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      if (span.superscript) {
        spanStyle = spanStyle.copyWith(
          fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 0.7 : 12.0,
        );
      }
      if (span.href != null) {
        spanStyle = spanStyle.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        );
      }
      spans.add(TextSpan(text: span.text, style: spanStyle));
    }
    return spans;
  }

  List<InlineSpan> _buildHighlightedSpans(String text, TextStyle style, String query) {
    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = regex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(
            color: Colors.amber,
            backgroundColor: Colors.black38,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }

  static TextDirection _effectiveTextDirection(
    BuildContext context,
    ReaderSettings settings,
  ) {
    switch (settings.textDirection) {
      case ReaderTextDirection.ltr:
        return TextDirection.ltr;
      case ReaderTextDirection.rtl:
        return TextDirection.rtl;
      case ReaderTextDirection.auto:
        return Directionality.of(context);
    }
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    final colors = widget.customColors ?? ReaderColors.forTheme(settings.theme);
    final String fontFamily;
    switch (settings.font) {
      case ReaderFont.inter:
        fontFamily = 'Inter';
        break;
      case ReaderFont.literata:
        fontFamily = 'Literata';
        break;
    }
    FontWeight fontWeight = FontWeight.normal;
    if (settings.fontWeightDelta > 0.33) {
      fontWeight = FontWeight.w600;
    } else if (settings.fontWeightDelta > 0) {
      fontWeight = FontWeight.w500;
    } else if (settings.fontWeightDelta < -0.33) {
      fontWeight = FontWeight.w300;
    } else if (settings.fontWeightDelta < 0) {
      fontWeight = FontWeight.w400;
    }
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: colors.text,
      letterSpacing: settings.letterSpacing,
      fontWeight: fontWeight,
    );
  }

  Widget _buildImageWidget(String imageUrl, Color? errorColor, [ReaderSettings? settings]) {
    final colorFilter = _imageColorFilter(settings);
    final uri = Uri.tryParse(imageUrl);
    final isDataUri = uri != null && uri.scheme == 'data';
    final isFileUri = uri != null && uri.scheme == 'file';
    final isPlainPath = uri == null || !uri.isAbsolute;

    if (isDataUri) {
      final data = imageUrl.split(',');
      if (data.length == 2) {
        final bytes = base64Decode(data.last);
        final img = InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (ctx, e, s) => Icon(
              Icons.broken_image,
              size: 64,
              color: errorColor,
            ),
          ),
        );
        return colorFilter != null ? ColorFiltered(colorFilter: colorFilter, child: img) : img;
      }
    }

    if (isFileUri || isPlainPath) {
      final filePath = isFileUri ? uri.path : imageUrl;
      final img = InteractiveViewer(
        maxScale: 4.0,
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (ctx, e, s) => Icon(
            Icons.broken_image,
            size: 64,
            color: errorColor,
          ),
        ),
      );
      return colorFilter != null ? ColorFiltered(colorFilter: colorFilter, child: img) : img;
    }

    return Icon(Icons.broken_image, size: 64, color: errorColor);
  }

  Widget _buildTable(ReaderBlock block, ReaderSettings settings) {
    final rows = block.tableRows;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final baseStyle = _getReaderStyle(settings);
    final cellStyle = baseStyle.copyWith(fontSize: settings.fontSize * 0.9);
    final headerStyle = cellStyle.copyWith(fontWeight: FontWeight.bold);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: (baseStyle.color ?? Colors.black).withValues(alpha: 0.15),
          ),
          children: rows.asMap().entries.map((entry) {
            final isHeader = entry.key == 0;
            return TableRow(
              children: entry.value.map((cell) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(cell, style: isHeader ? headerStyle : cellStyle),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(ReaderBlock block, ReaderSettings settings, TextAlign textAlign) {
    final items = block.listItems;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final isOrdered = block.ordered ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
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
                Text(
                  '$bullet ',
                  style: _getReaderStyle(settings),
                ),
                Expanded(
                  child: _buildHighlightedText(
                    item.text,
                    _getReaderStyle(settings),
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
}

class _PaginatedContentBody extends StatefulWidget {
  const _PaginatedContentBody({
    required this.metadata,
    required this.loadedChapters,
    required this.settings,
    required this.onTap,
    required this.initialPage,
    this.highlightQuery,
    this.ttsHighlightIndex,
    this.chapterHighlights = const <int, List<TextHighlight>>{},
    this.blockTransformers,
    this.customColors,
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final GestureTapUpCallback onTap;
  final int initialPage;
  final String? highlightQuery;
  final int? ttsHighlightIndex;
  final Map<int, List<TextHighlight>> chapterHighlights;
  final List<BlockTransformer>? blockTransformers;
  final ReaderColors? customColors;

  @override
  State<_PaginatedContentBody> createState() => _PaginatedContentBodyState();
}

class _PageContent {
  final int chapterIndex;
  final int blockStart;
  final int blockEnd;
  final bool showChapterTitle;

  const _PageContent({
    required this.chapterIndex,
    required this.blockStart,
    required this.blockEnd,
    this.showChapterTitle = false,
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
          currentHeight += blockHeight;
        }
      }

      pages.add(
        _PageContent(
          chapterIndex: chIdx,
          blockStart: pageStart,
          blockEnd: chapter.blocks.length,
          showChapterTitle: pages.isEmpty || pages.last.chapterIndex != chIdx,
        ),
      );
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
        final scale = switch (level) {
          1 => 1.6,
          2 => 1.4,
          3 => 1.2,
          _ => 1.1,
        };
        final spacing = switch (level) {
          1 => ps * 3,
          2 => ps * 2,
          _ => ps * 1.5,
        };
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
        return settings.fontSize * 8;
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
        return _measureTextHeight(block.text, settings.fontSize, settings.lineHeight, width) + ps;
    }
  }

  double _measureTextHeight(String text, double fontSize, double lineHeight, double maxWidth) {
    if (text.isEmpty) return fontSize * lineHeight;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          letterSpacing: widget.settings.letterSpacing,
        ),
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
    final chapter = widget.loadedChapters[page.chapterIndex];
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };
    final chapterHighlights = widget.chapterHighlights[page.chapterIndex];

    if (chapter == null) {
      return _buildLoadingPlaceholder(settings, page.chapterIndex);
    }

    final style = _getReaderStyle(settings);
    final content = <Widget>[];

    if (page.showChapterTitle && chapter.title.isNotEmpty) {
      content.add(
        Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
          child: _buildHighlightedText(
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
      content.add(
        _buildBlock(
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
        textDirection: _effectiveTextDirection(context),
        child: Padding(
          padding: EdgeInsets.all(settings.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ReaderSettings settings, int index) {
    final title = index < widget.metadata.chapterTitles.length
        ? widget.metadata.chapterTitles[index]
        : 'Глава ${index + 1}';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: settings.paragraphSpacing * 3),
          Center(
            child: SizedBox(
              width: settings.fontSize * 1.5,
              height: settings.fontSize * 1.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _getReaderStyle(settings).color?.withValues(alpha: 0.3),
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
                  color: _getReaderStyle(settings).color?.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(
    ReaderBlock block,
    TextAlign textAlign, {
    List<TextHighlight>? blockHighlights,
  }) {
    final settings = widget.settings;
    final style = _getReaderStyle(settings);

    switch (block.type) {
      case BlockType.heading:
        final level = block.headingLevel ?? 2;
        final scale = switch (level) {
          1 => 1.6,
          2 => 1.4,
          3 => 1.2,
          _ => 1.1,
        };
        final spacing = switch (level) {
          1 => settings.paragraphSpacing * 3,
          2 => settings.paragraphSpacing * 2,
          _ => settings.paragraphSpacing * 1.5,
        };
        return Padding(
          padding: EdgeInsets.only(top: spacing, bottom: settings.paragraphSpacing),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(
              fontSize: settings.fontSize * scale,
              fontWeight: level <= 2 ? FontWeight.bold : FontWeight.w600,
            ),
            block.textAlign ?? textAlign,
          ),
        );
      case BlockType.subtitle:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(
              fontSize: settings.fontSize * 1.1,
              fontStyle: FontStyle.italic,
            ),
            block.textAlign ?? TextAlign.center,
          ),
        );
      case BlockType.epigraph:
        return Container(
          margin: EdgeInsets.symmetric(
            vertical: settings.paragraphSpacing * 2,
            horizontal: settings.margin * 0.5,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildHighlightedText(
                block.text,
                style.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: settings.fontSize * 0.95,
                ),
                TextAlign.right,
              ),
            ],
          ),
        );
      case BlockType.poem:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(fontStyle: FontStyle.italic),
            TextAlign.center,
          ),
        );
      case BlockType.cite:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: (style.color ?? Colors.black).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(fontStyle: FontStyle.italic),
            TextAlign.left,
          ),
        );
      case BlockType.textAuthor:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing,
            left: settings.margin,
          ),
          child: Text(
            '— ${block.text}',
            style: style.copyWith(
              fontSize: settings.fontSize * 0.9,
              fontStyle: FontStyle.italic,
              color: (style.color ?? Colors.black).withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.right,
          ),
        );
      case BlockType.quote:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: (style.color ?? Colors.black).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(fontStyle: FontStyle.italic),
            textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: style)),
        );
      case BlockType.image:
        if (!widget.settings.showImages) return const SizedBox.shrink();
        if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Align(
              alignment: switch (widget.settings.imageAlignment) {
                ImageAlignment.start => Alignment.centerLeft,
                ImageAlignment.center => Alignment.center,
                ImageAlignment.end => Alignment.centerRight,
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600 * widget.settings.imageWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.settings.imageCornerRadius),
                  child: _buildImageWidget(block.imageUrl!, style.color, widget.settings),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case BlockType.footnote:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing / 2),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(fontSize: settings.fontSize * 0.85),
            textAlign,
          ),
        );
      case BlockType.table:
        return _buildTable(block, settings);
      case BlockType.list:
        return _buildList(block, settings, textAlign);
      case BlockType.paragraph:
        final indent = (block.textIndent != null && block.textIndent! > 0)
            ? EdgeInsets.only(left: block.textIndent!)
            : (settings.paragraphFirstLineIndent > 0
                  ? EdgeInsets.only(left: settings.paragraphFirstLineIndent)
                  : EdgeInsets.zero);
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Padding(
            padding: indent,
            child: blockHighlights != null && blockHighlights.isNotEmpty
                ? HighlightedText(
                    text: block.text,
                    style: style,
                    textAlign: block.textAlign ?? textAlign,
                    highlights: blockHighlights,
                  )
                : _buildHighlightedText(
                    block.text,
                    style,
                    block.textAlign ?? textAlign,
                    richSpans: block.richSpans,
                  ),
          ),
        );
    }
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle style,
    TextAlign textAlign, {
    List<RichSpan>? richSpans,
  }) {
    final query = widget.highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      if (richSpans != null && richSpans.isNotEmpty) {
        return Text.rich(
          TextSpan(children: _buildRichTextSpans(richSpans, style)),
          textAlign: textAlign,
        );
      }
      if (widget.settings.bionicReading) {
        return Text.rich(
          TextSpan(children: _bionicReadingSpans(text, style)),
          textAlign: textAlign,
        );
      }
      return Text(text, style: style, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(children: _buildHighlightedSpans(text, style, query)),
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildRichTextSpans(List<RichSpan> richSpans, TextStyle baseStyle) {
    final linkColor = Theme.of(context).colorScheme.primary;
    final spans = <InlineSpan>[];
    for (final span in richSpans) {
      if (span.lineBreak) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      var spanStyle = baseStyle;
      if (span.bold) spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      if (span.italic) spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      if (span.superscript) {
        spanStyle = spanStyle.copyWith(
          fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 0.7 : 12.0,
        );
      }
      if (span.href != null) {
        spanStyle = spanStyle.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
        );
      }
      spans.add(TextSpan(text: span.text, style: spanStyle));
    }
    return spans;
  }

  List<InlineSpan> _buildHighlightedSpans(String text, TextStyle style, String query) {
    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = regex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: style));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(
            color: Colors.amber,
            backgroundColor: Colors.black38,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return spans;
  }

  TextDirection _effectiveTextDirection(BuildContext context) {
    switch (widget.settings.textDirection) {
      case ReaderTextDirection.ltr:
        return TextDirection.ltr;
      case ReaderTextDirection.rtl:
        return TextDirection.rtl;
      case ReaderTextDirection.auto:
        return Directionality.of(context);
    }
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    final colors = widget.customColors ?? ReaderColors.forTheme(settings.theme);
    final String fontFamily;
    switch (settings.font) {
      case ReaderFont.inter:
        fontFamily = 'Inter';
        break;
      case ReaderFont.literata:
        fontFamily = 'Literata';
        break;
    }
    FontWeight fontWeight = FontWeight.normal;
    if (settings.fontWeightDelta > 0.33) {
      fontWeight = FontWeight.w600;
    } else if (settings.fontWeightDelta > 0) {
      fontWeight = FontWeight.w500;
    } else if (settings.fontWeightDelta < -0.33) {
      fontWeight = FontWeight.w300;
    } else if (settings.fontWeightDelta < 0) {
      fontWeight = FontWeight.w400;
    }
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: colors.text,
      letterSpacing: settings.letterSpacing,
      fontWeight: fontWeight,
    );
  }

  Widget _buildPage(int index, BuildContext context) {
    if (index < _pages.length) {
      return _buildPaginatedPage(index, context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildTwoPage(int index, BuildContext context) {
    final leftIndex = index * 2;
    final rightIndex = index * 2 + 1;
    return Directionality(
      textDirection: _effectiveTextDirection(context),
      child: Row(
        children: [
          Expanded(
            child: leftIndex < _pages.length
                ? _buildPaginatedPage(leftIndex, context)
                : const SizedBox.shrink(),
          ),
          Container(
            width: 1,
            color: ReaderColors.forTheme(widget.settings.theme).text.withValues(alpha: 0.1),
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

        final isTwoPage = widget.settings.mode == ReaderMode.twoPage;
        final useTwoPageLayout = isTwoPage && context.canUseTwoPageMode;
        final effectivePageCount = useTwoPageLayout ? ((pageCount + 1) ~/ 2) : pageCount;

        if (!_didRestoreInitialPage && widget.initialPage > 0) {
          final targetPage = (useTwoPageLayout ? widget.initialPage ~/ 2 : widget.initialPage)
              .clamp(
                0,
                effectivePageCount - 1,
              );
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
          return _buildPage(index, context);
        }

        Widget pageContent;
        switch (widget.settings.pageTurnAnimation) {
          case PageTurnAnimation.none:
            pageContent = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: widget.onTap,
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                padEnds: false,
                itemCount: effectivePageCount,
                itemBuilder: itemBuilder,
              ),
            );

          case PageTurnAnimation.fade:
            pageContent = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: widget.onTap,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                padEnds: false,
                itemCount: effectivePageCount,
                itemBuilder: (context, index) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: itemBuilder(context, index),
                  );
                },
              ),
            );

          case PageTurnAnimation.curl:
            pageContent = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: widget.onTap,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                padEnds: false,
                itemCount: effectivePageCount,
                itemBuilder: (context, index) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: itemBuilder(context, index),
                  );
                },
              ),
            );

          case PageTurnAnimation.slide:
            pageContent = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: widget.onTap,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                padEnds: false,
                itemCount: effectivePageCount,
                itemBuilder: itemBuilder,
              ),
            );
        }

        if (widget.settings.perceptionExpander || widget.settings.horizontalLimiter) {
          final colors = ReaderColors.forTheme(widget.settings.theme);
          return Stack(
            children: [
              pageContent,
              if (widget.settings.perceptionExpander) ...[
                Positioned(
                  left: widget.settings.margin - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: colors.text.withValues(alpha: 0.15),
                  ),
                ),
                Positioned(
                  right: widget.settings.margin - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: colors.text.withValues(alpha: 0.15),
                  ),
                ),
              ],
              if (widget.settings.horizontalLimiter) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _limiterTopOffset(widget.settings),
                  child: ColoredBox(
                    color: colors.text.withValues(alpha: widget.settings.horizontalLimiterDimming),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _limiterBottomOffset(widget.settings),
                  child: ColoredBox(
                    color: colors.text.withValues(alpha: widget.settings.horizontalLimiterDimming),
                  ),
                ),
                if (widget.settings.horizontalLimiterLines) ...[
                  Positioned(
                    left: widget.settings.margin,
                    right: widget.settings.margin,
                    top: _limiterTopOffset(widget.settings),
                    child: Container(
                      height: 1,
                      color: colors.text.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    left: widget.settings.margin,
                    right: widget.settings.margin,
                    bottom: _limiterBottomOffset(widget.settings),
                    child: Container(
                      height: 1,
                      color: colors.text.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ],
            ],
          );
        }
        return pageContent;
      },
    );
  }

  Widget _buildImageWidget(String imageUrl, Color? errorColor, [ReaderSettings? settings]) {
    final colorFilter = _imageColorFilter(settings);
    final uri = Uri.tryParse(imageUrl);
    final isDataUri = uri != null && uri.scheme == 'data';
    final isFileUri = uri != null && uri.scheme == 'file';
    final isPlainPath = uri == null || !uri.isAbsolute;

    if (isDataUri) {
      final data = imageUrl.split(',');
      if (data.length == 2) {
        final bytes = base64Decode(data.last);
        final img = InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (ctx, e, s) => Icon(
              Icons.broken_image,
              size: 64,
              color: errorColor,
            ),
          ),
        );
        return colorFilter != null ? ColorFiltered(colorFilter: colorFilter, child: img) : img;
      }
    }

    if (isFileUri || isPlainPath) {
      final filePath = isFileUri ? uri.path : imageUrl;
      final img = InteractiveViewer(
        maxScale: 4.0,
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (ctx, e, s) => Icon(
            Icons.broken_image,
            size: 64,
            color: errorColor,
          ),
        ),
      );
      return colorFilter != null ? ColorFiltered(colorFilter: colorFilter, child: img) : img;
    }

    return Icon(Icons.broken_image, size: 64, color: errorColor);
  }

  Widget _buildTable(ReaderBlock block, ReaderSettings settings) {
    final rows = block.tableRows;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final baseStyle = _getReaderStyle(settings);
    final cellStyle = baseStyle.copyWith(fontSize: settings.fontSize * 0.9);
    final headerStyle = cellStyle.copyWith(fontWeight: FontWeight.bold);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: (baseStyle.color ?? Colors.black).withValues(alpha: 0.15),
          ),
          children: rows.asMap().entries.map((entry) {
            final isHeader = entry.key == 0;
            return TableRow(
              children: entry.value.map((cell) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(cell, style: isHeader ? headerStyle : cellStyle),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList(ReaderBlock block, ReaderSettings settings, TextAlign textAlign) {
    final items = block.listItems;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final isOrdered = block.ordered ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
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
                Text('$bullet ', style: _getReaderStyle(settings)),
                Expanded(
                  child: _buildHighlightedText(
                    item.text,
                    _getReaderStyle(settings),
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
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
