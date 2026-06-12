import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/platform/adaptive_context.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';

class ReaderContentBody extends StatelessWidget {
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
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final ScrollController scrollController;
  final GestureTapUpCallback onTap;
  final double initialProgress;
  final int initialPage;
  final String? highlightQuery;

  @override
  Widget build(BuildContext context) {
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      return _PaginatedContentBody(
        metadata: metadata,
        loadedChapters: loadedChapters,
        settings: settings,
        onTap: onTap,
        initialPage: initialPage,
        highlightQuery: highlightQuery,
      );
    }

    final isFocus = settings.mode == ReaderMode.focus || settings.mode == ReaderMode.fullscreen;
    final effectiveMargin = isFocus
        ? EdgeInsets.symmetric(
            horizontal: settings.margin * 1.5,
            vertical: settings.margin,
          )
        : EdgeInsets.all(settings.margin);
    final textDirection = _effectiveTextDirection(context, settings);

    if (initialProgress > 0 && scrollController.hasClients) {
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
                  if (!isLast)
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
    );
  }

  Widget _buildLoadingPlaceholder(ReaderSettings settings, int index) {
    final title = index < metadata.chapterTitles.length
        ? metadata.chapterTitles[index]
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

    if (chapter.blocks.length <= 50) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...chapter.blocks.map((block) => _buildBlock(block, settings, textAlign)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ...chapter.blocks.map((block) => _buildBlock(block, settings, textAlign)),
      ],
    );
  }

  Widget _buildBlock(
    ReaderBlock block,
    ReaderSettings settings,
    TextAlign textAlign,
  ) {
    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: _buildHighlightedText(
            block.text,
            _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
            textAlign,
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
            _getReaderStyle(settings).copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: _getReaderStyle(settings))),
        );
      case BlockType.image:
        if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
          final uri = Uri.tryParse(block.imageUrl!);
          final isLocal = uri == null || !uri.isAbsolute || uri.scheme == 'file';
          if (!isLocal) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
              child: Center(
                child: Icon(Icons.broken_image, size: 64, color: _getReaderStyle(settings).color),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(block.imageUrl!),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, e, s) => Icon(
                    Icons.broken_image,
                    size: 64,
                    color: _getReaderStyle(settings).color,
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
      case BlockType.paragraph:
        final indent = settings.paragraphFirstLineIndent > 0
            ? EdgeInsets.only(left: settings.paragraphFirstLineIndent)
            : EdgeInsets.zero;
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Padding(
            padding: indent,
            child: _buildHighlightedText(block.text, _getReaderStyle(settings), textAlign),
          ),
        );
    }
  }

  Widget _buildHighlightedText(String text, TextStyle style, TextAlign textAlign) {
    final query = highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      return Text(text, style: style, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(children: _buildHighlightedSpans(text, style, query)),
      textAlign: textAlign,
    );
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
    final colors = ReaderColors.forTheme(settings.theme);
    final String fontFamily;
    switch (settings.font) {
      case ReaderFont.inter:
        fontFamily = 'Inter';
        break;
      case ReaderFont.literata:
        fontFamily = 'Literata';
        break;
    }
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: colors.text,
      letterSpacing: settings.letterSpacing,
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
  });

  final NormalizedBookMetadata metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderSettings settings;
  final GestureTapUpCallback onTap;
  final int initialPage;
  final String? highlightQuery;

  @override
  State<_PaginatedContentBody> createState() => _PaginatedContentBodyState();
}

class _PaginatedContentBodyState extends State<_PaginatedContentBody> {
  late final PageController _pageController;
  bool _didRestoreInitialPage = false;
  bool _disposed = false;

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
        final isTwoPage = widget.settings.mode == ReaderMode.twoPage;
        final useTwoPageLayout = isTwoPage && context.canUseTwoPageMode;
        final pageCount = useTwoPageLayout
            ? ((widget.metadata.chapterCount + 1) ~/ 2)
            : widget.metadata.chapterCount;
        if (pageCount == 0) return;
        final targetPage = (useTwoPageLayout ? widget.initialPage ~/ 2 : widget.initialPage).clamp(
          0,
          pageCount - 1,
        );
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

  Widget _buildChapterContent(int chapterIndex) {
    final settings = widget.settings;
    final chapter = widget.loadedChapters[chapterIndex];
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    if (chapter == null) {
      return _buildLoadingPlaceholder(settings, chapterIndex);
    }

    final style = _getReaderStyle(settings);
    final header = chapter.title.isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
            child: _buildHighlightedText(
              chapter.title,
              style.copyWith(
                fontSize: settings.fontSize * 1.4,
                fontWeight: FontWeight.bold,
              ),
              textAlign,
            ),
          )
        : const SizedBox.shrink();

    if (chapter.blocks.length <= 50) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...chapter.blocks.map((block) => _buildBlock(block, textAlign)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapter.blocks.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (context, i) => _buildBlock(chapter.blocks[i], textAlign),
        ),
      ],
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

  Widget _buildBlock(ReaderBlock block, TextAlign textAlign) {
    final settings = widget.settings;
    final style = _getReaderStyle(settings);

    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: _buildHighlightedText(
            block.text,
            style.copyWith(
              fontSize: settings.fontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
            textAlign,
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
        if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
          final uri = Uri.tryParse(block.imageUrl!);
          final isLocal = uri == null || !uri.isAbsolute || uri.scheme == 'file';
          if (!isLocal) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
              child: Center(child: Icon(Icons.broken_image, size: 64, color: style.color)),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(block.imageUrl!),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, e, s) => Icon(
                    Icons.broken_image,
                    size: 64,
                    color: style.color,
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
            style.copyWith(
              fontSize: settings.fontSize * 0.85,
            ),
            textAlign,
          ),
        );
      case BlockType.paragraph:
        final indent = settings.paragraphFirstLineIndent > 0
            ? EdgeInsets.only(left: settings.paragraphFirstLineIndent)
            : EdgeInsets.zero;
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Padding(
            padding: indent,
            child: _buildHighlightedText(block.text, style, textAlign),
          ),
        );
    }
  }

  Widget _buildHighlightedText(String text, TextStyle style, TextAlign textAlign) {
    final query = widget.highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      return Text(text, style: style, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(children: _buildHighlightedSpans(text, style, query)),
      textAlign: textAlign,
    );
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
    final colors = ReaderColors.forTheme(settings.theme);
    final String fontFamily;
    switch (settings.font) {
      case ReaderFont.inter:
        fontFamily = 'Inter';
        break;
      case ReaderFont.literata:
        fontFamily = 'Literata';
        break;
    }
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      color: colors.text,
      letterSpacing: settings.letterSpacing,
    );
  }

  Widget _buildPage(int index, BuildContext context) {
    return SafeArea(
      key: ValueKey(index),
      top: false,
      bottom: false,
      child: Directionality(
        textDirection: _effectiveTextDirection(context),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(widget.settings.margin),
          child: _buildChapterContent(index),
        ),
      ),
    );
  }

  Widget _buildTwoPage(int index, BuildContext context) {
    final leftIndex = index * 2;
    final rightIndex = index * 2 + 1;
    return Directionality(
      textDirection: _effectiveTextDirection(context),
      child: Row(
        children: [
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(widget.settings.margin),
                child: _buildChapterContent(leftIndex),
              ),
            ),
          ),
          Container(
            width: 1,
            color: ReaderColors.forTheme(widget.settings.theme).text.withValues(alpha: 0.1),
          ),
          Expanded(
            child: rightIndex < widget.metadata.chapterCount
                ? SafeArea(
                    top: false,
                    bottom: false,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(widget.settings.margin),
                      child: _buildChapterContent(rightIndex),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTwoPage = widget.settings.mode == ReaderMode.twoPage;
    final useTwoPageLayout = isTwoPage && context.canUseTwoPageMode;
    final pageCount = useTwoPageLayout
        ? ((widget.metadata.chapterCount + 1) ~/ 2)
        : widget.metadata.chapterCount;
    if (!_didRestoreInitialPage && widget.initialPage > 0 && pageCount > 0) {
      final targetPage = (useTwoPageLayout ? widget.initialPage ~/ 2 : widget.initialPage).clamp(
        0,
        pageCount - 1,
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

    switch (widget.settings.pageTurnAnimation) {
      case PageTurnAnimation.none:
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTap,
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pageCount,
            itemBuilder: (context, index) {
              return useTwoPageLayout ? _buildTwoPage(index, context) : _buildPage(index, context);
            },
          ),
        );

      case PageTurnAnimation.fade:
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTap,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: pageCount,
            itemBuilder: (context, index) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: useTwoPageLayout
                    ? _buildTwoPage(index, context)
                    : _buildPage(index, context),
              );
            },
          ),
        );

      case PageTurnAnimation.curl:
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTap,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: pageCount,
            itemBuilder: (context, index) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: useTwoPageLayout
                    ? _buildTwoPage(index, context)
                    : _buildPage(index, context),
              );
            },
          ),
        );

      case PageTurnAnimation.slide:
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: widget.onTap,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: pageCount,
            itemBuilder: (context, index) {
              return useTwoPageLayout ? _buildTwoPage(index, context) : _buildPage(index, context);
            },
          ),
        );
    }
  }
}
