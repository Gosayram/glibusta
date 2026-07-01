import 'package:flutter/material.dart';

import '../data/reader_colors.dart';
import '../domain/reader.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.settings,
    required this.bookTitle,
    required this.onBack,
    this.bookAuthor,
    this.onSearch,
    this.onToc,
    this.onBookmark,
    this.onMore,
    this.isBookmarked = false,
    this.hasLinkBack = false,
    this.onBookInfo,
  });

  final ReaderSettings settings;
  final String bookTitle;
  final VoidCallback onBack;
  final String? bookAuthor;
  final VoidCallback? onSearch;
  final VoidCallback? onToc;
  final VoidCallback? onBookmark;
  final VoidCallback? onMore;
  final bool isBookmarked;
  final bool hasLinkBack;
  final VoidCallback? onBookInfo;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showTitle = screenWidth > 400; // ponytail: hide title on small screens
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.85),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // HG-22.3: link back history indicator
            Semantics(
              button: true,
              label: 'Назад',
              child: IconButton(
                icon: hasLinkBack
                    ? const Icon(Icons.subdirectory_arrow_left)
                    : const Icon(Icons.arrow_back),
                color: colors.text,
                tooltip: hasLinkBack ? 'Назад по ссылке' : 'Назад',
                onPressed: onBack,
              ),
            ),
            Expanded(
              child: showTitle
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookTitle,
                          style: TextStyle(color: colors.text, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          semanticsLabel: 'Книга: $bookTitle',
                        ),
                        if (bookAuthor != null && bookAuthor!.isNotEmpty)
                          Text(
                            bookAuthor!,
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            if (onSearch != null)
              Semantics(
                button: true,
                label: 'Поиск по книге',
                child: IconButton(
                  icon: const Icon(Icons.search),
                  color: colors.text,
                  tooltip: 'Поиск по книге',
                  onPressed: onSearch,
                ),
              ),
            if (onToc != null)
              Semantics(
                button: true,
                label: 'Содержание',
                child: IconButton(
                  icon: const Icon(Icons.list),
                  color: colors.text,
                  tooltip: 'Содержание',
                  onPressed: onToc,
                ),
              ),
            if (onBookmark != null)
              Semantics(
                button: true,
                label: isBookmarked ? 'Убрать закладку' : 'Добавить закладку',
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.amber : colors.text,
                  ),
                  tooltip: isBookmarked ? 'Убрать закладку' : 'Добавить закладку',
                  onPressed: onBookmark,
                ),
              ),
            if (onBookInfo != null)
              Semantics(
                button: true,
                label: 'О книге',
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: colors.text,
                  tooltip: 'О книге',
                  onPressed: onBookInfo,
                ),
              ),
            Semantics(
              button: true,
              label: 'Настройки',
              child: IconButton(
                icon: const Icon(Icons.settings),
                color: colors.text,
                tooltip: 'Настройки',
                onPressed: onMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.settings,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.scrollProgress,
    required this.estimatedMinutesLeft,
    required this.chapterTitle,
    this.chapterTitleAt,
    this.onJumpToProgress,
    this.onModeChanged,
    this.checkpoints = const [],
    this.onCheckpointForward,
    this.onCheckpointBack,
  });

  final ReaderSettings settings;
  final int currentChapterIndex;
  final int totalChapters;
  final double scrollProgress;
  final int estimatedMinutesLeft;
  final String chapterTitle;
  final String Function(int chapterIndex)? chapterTitleAt;
  final ValueChanged<double>? onJumpToProgress;
  final ValueChanged<ReaderMode>? onModeChanged;
  final List<double> checkpoints;
  final VoidCallback? onCheckpointForward;
  final VoidCallback? onCheckpointBack;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    if (settings.bottomBarContent == BottomBarContent.none) {
      return const SizedBox.shrink();
    }

    final percent = (scrollProgress * 100).round();
    final page = (scrollProgress * totalChapters).ceil().clamp(1, totalChapters);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.85),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapterTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  chapterTitle,
                  style: TextStyle(
                    color: colors.text.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _leftLabel(settings, page, totalChapters, percent),
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
                Text(
                  _rightLabel(settings, page, totalChapters, percent, estimatedMinutesLeft),
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
              ],
            ),
            if (onJumpToProgress != null) ...[
              const SizedBox(height: 4),
              _SliderWithPreview(
                value: scrollProgress,
                totalChapters: totalChapters,
                currentChapterIndex: currentChapterIndex,
                settings: settings,
                colors: colors,
                onChanged: onJumpToProgress!,
                chapterTitleAt: chapterTitleAt,
                checkpoints: checkpoints,
                onCheckpointBack: onCheckpointBack,
                onCheckpointForward: onCheckpointForward,
              ),
            ],
            if (onModeChanged != null) _buildModeSwitcher(colors),
          ],
        ),
      ),
    );
  }

  String _leftLabel(ReaderSettings settings, int page, int totalChapters, int percent) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return '$page / $totalChapters';
      case BottomBarContent.percent:
        return '$percent%';
      case BottomBarContent.chapter:
        return '$page / $totalChapters';
      case BottomBarContent.time:
        return '$page / $totalChapters';
      case BottomBarContent.none:
        return '';
    }
  }

  String _rightLabel(
    ReaderSettings settings,
    int page,
    int totalChapters,
    int percent,
    int minutesLeft,
  ) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return '$percent%';
      case BottomBarContent.percent:
        return '$page / $totalChapters';
      case BottomBarContent.chapter:
        return '$percent%';
      case BottomBarContent.time:
        return minutesLeft > 0 ? '~$minutesLeft мин' : '$percent%';
      case BottomBarContent.none:
        return '';
    }
  }

  Widget _buildModeSwitcher(ReaderColors colors) {
    const modes = <ReaderMode, String>{
      ReaderMode.paginated: 'Страницы',
      ReaderMode.continuous: 'Прокрутка',
      ReaderMode.focus: 'Фокус',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.entries.map((entry) {
        final isSelected = settings.mode == entry.key;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            button: true,
            label: entry.value,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => onModeChanged?.call(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.text.withValues(alpha: 0.15)
                      : colors.text.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? colors.text.withValues(alpha: 0.3)
                        : colors.text.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? colors.text : colors.text.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.scrollProgress,
    required this.theme,
  });

  final double scrollProgress;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: LinearProgressIndicator(
          value: scrollProgress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            ReaderColors.progressColor(theme),
          ),
        ),
      ),
    );
  }
}

class _CheckpointMarkerPainter extends CustomPainter {
  _CheckpointMarkerPainter({
    required this.checkpoints,
    required this.color,
    this.totalChapters = 0,
  });

  final List<double> checkpoints;
  final Color color;
  final int totalChapters;

  @override
  void paint(Canvas canvas, Size size) {
    // Chapter boundary markers — thin dots
    if (totalChapters > 1) {
      final dotPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < totalChapters; i++) {
        final x = (i / totalChapters).clamp(0.0, 1.0) * size.width;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), dotPaint);
      }
    }

    // Checkpoint markers — thick lines
    final cpPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final cp in checkpoints) {
      final x = cp.clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cpPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckpointMarkerPainter oldDelegate) =>
      checkpoints != oldDelegate.checkpoints || totalChapters != oldDelegate.totalChapters;
}

class _SliderWithPreview extends StatefulWidget {
  const _SliderWithPreview({
    required this.value,
    required this.totalChapters,
    required this.currentChapterIndex,
    required this.settings,
    required this.colors,
    required this.onChanged,
    this.chapterTitleAt,
    this.checkpoints = const [],
    this.onCheckpointBack,
    this.onCheckpointForward,
  });

  final double value;
  final int totalChapters;
  final int currentChapterIndex;
  final ReaderSettings settings;
  final ReaderColors colors;
  final ValueChanged<double> onChanged;
  final String Function(int chapterIndex)? chapterTitleAt;
  final List<double> checkpoints;
  final VoidCallback? onCheckpointBack;
  final VoidCallback? onCheckpointForward;

  @override
  State<_SliderWithPreview> createState() => _SliderWithPreviewState();
}

class _SliderWithPreviewState extends State<_SliderWithPreview> {
  bool _dragging = false;
  double _dragValue = 0;
  double _preDragValue = 0;

  @override
  Widget build(BuildContext context) {
    final value = _dragging ? _dragValue : widget.value;
    final dragPercent = (value * 100).round();
    final dragChapter = (value * widget.totalChapters).ceil().clamp(1, widget.totalChapters);
    final moved = _dragging && (value - _preDragValue).abs() > 0.005;
    final chapterTitle = widget.chapterTitleAt?.call(dragChapter - 1) ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_dragging)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.colors.text.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chapterTitle.isNotEmpty)
                    Text(
                      chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.colors.scaffold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Глава $dragChapter / ${widget.totalChapters}  ·  $dragPercent%',
                        style: TextStyle(
                          color: widget.colors.scaffold.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (moved) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _dragValue = _preDragValue;
                              _dragging = false;
                            });
                            widget.onChanged(_preDragValue);
                          },
                          child: Text(
                            'Отмена',
                            style: TextStyle(
                              color: widget.colors.scaffold.withValues(alpha: 0.7),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            if (widget.onCheckpointBack != null)
              GestureDetector(
                onTap: widget.onCheckpointBack,
                child: Icon(
                  Icons.bookmark,
                  size: 16,
                  color: widget.checkpoints.any((c) => c < widget.value - 0.02)
                      ? widget.colors.text.withValues(alpha: 0.6)
                      : widget.colors.text.withValues(alpha: 0.15),
                ),
              ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: widget.colors.text.withValues(alpha: 0.4),
                  inactiveTrackColor: widget.colors.text.withValues(alpha: 0.15),
                  thumbColor: widget.colors.text.withValues(alpha: 0.7),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 2,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChangeStart: (v) => setState(() {
                    _dragging = true;
                    _dragValue = v;
                    _preDragValue = widget.value;
                  }),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    setState(() => _dragging = false);
                    widget.onChanged(v);
                  },
                ),
              ),
            ),
            if (widget.onCheckpointForward != null)
              GestureDetector(
                onTap: widget.onCheckpointForward,
                child: Icon(
                  Icons.bookmark,
                  size: 16,
                  color: widget.checkpoints.any((c) => c > widget.value + 0.02)
                      ? widget.colors.text.withValues(alpha: 0.6)
                      : widget.colors.text.withValues(alpha: 0.15),
                ),
              ),
          ],
        ),
        if (widget.totalChapters > 1 || widget.checkpoints.isNotEmpty)
          SizedBox(
            height: 6,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CheckpointMarkerPainter(
                checkpoints: widget.checkpoints,
                color: widget.colors.text,
                totalChapters: widget.totalChapters,
              ),
            ),
          ),
      ],
    );
  }
}
