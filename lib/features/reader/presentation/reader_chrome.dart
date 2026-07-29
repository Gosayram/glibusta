import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/reader_colors.dart';
import '../domain/reader.dart';

/// Explains the reader controls that are temporarily revealed by a central tap.
///
/// This intentionally documents the current shared chrome behavior instead of
/// introducing separate visibility preferences before their interaction and
/// accessibility policy is defined.
class ReaderChromeVisibilityGuide extends StatelessWidget {
  const ReaderChromeVisibilityGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('reader_chrome_visibility_guide'),
      container: true,
      label:
          'Панели чтения. Центральное касание показывает или скрывает верхнюю и '
          'нижнюю панель. Верхняя панель содержит содержание, поиск и настройки. '
          'Нижняя показывает прогресс и режим чтения. Время автоскрытия настраивается '
          'ниже. Строки информации на странице настраиваются в настройках приложения.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.touch_app_outlined, color: colors.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Панели чтения', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      'Коснитесь центра страницы, чтобы показать или скрыть обе панели. '
                      'Верхняя открывает содержание, поиск и настройки; нижняя — прогресс '
                      'и режим чтения.',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Время автоскрытия меняется ниже. Строки информации сверху и снизу '
                      'настраиваются в настройках приложения.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    this.hasLinkForward = false,
    this.onLinkForward,
    this.onBookInfo,
    this.onKaraoke,
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
  final bool hasLinkForward;
  final VoidCallback? onLinkForward;
  final VoidCallback? onBookInfo;
  final VoidCallback? onKaraoke;

  @override
  Widget build(BuildContext context) {
    final colors = ReaderColors.forTheme(settings.theme);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showTitle = screenWidth > 400; // ponytail: hide title on small screens
    final bookLabel = bookAuthor?.isNotEmpty == true
        ? 'Книга: $bookTitle. Автор: $bookAuthor'
        : 'Книга: $bookTitle';
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
            if (hasLinkForward)
              Semantics(
                button: true,
                label: 'Вперёд по ссылке',
                child: IconButton(
                  icon: const Icon(Icons.subdirectory_arrow_right),
                  color: colors.text,
                  tooltip: 'Вперёд по ссылке',
                  onPressed: onLinkForward,
                ),
              ),
            Expanded(
              child: Semantics(
                label: bookLabel,
                child: ExcludeSemantics(
                  child: showTitle
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookTitle,
                              style: TextStyle(color: colors.text, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
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
              ),
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
            // LW-6.1: karaoke audio sync button
            if (onKaraoke != null)
              Semantics(
                button: true,
                label: 'Аудиосинхронизация',
                child: IconButton(
                  icon: const Icon(Icons.music_note),
                  color: colors.text,
                  tooltip: 'Аудиосинхронизация',
                  onPressed: onKaraoke,
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
    final safeTotalChapters = totalChapters > 0 ? totalChapters : 1;
    final currentChapter = currentChapterIndex.clamp(0, safeTotalChapters - 1) + 1;
    final chapterPosition = 'Глава $currentChapter из $safeTotalChapters';

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
                child: Semantics(
                  header: true,
                  label: 'Текущая глава: $chapterTitle',
                  child: ExcludeSemantics(
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
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: 'Позиция чтения: $chapterPosition',
                  child: ExcludeSemantics(
                    child: Text(
                      _leftLabel(settings, chapterPosition, percent),
                      style: TextStyle(color: colors.text, fontSize: 12),
                    ),
                  ),
                ),
                Text(
                  _rightLabel(settings, chapterPosition, percent, estimatedMinutesLeft),
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

  String _leftLabel(ReaderSettings settings, String chapterPosition, int percent) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return chapterPosition;
      case BottomBarContent.percent:
        return '$percent%';
      case BottomBarContent.chapter:
        return chapterPosition;
      case BottomBarContent.time:
        return chapterPosition;
      case BottomBarContent.none:
        return '';
    }
  }

  String _rightLabel(
    ReaderSettings settings,
    String chapterPosition,
    int percent,
    int minutesLeft,
  ) {
    switch (settings.bottomBarContent) {
      case BottomBarContent.page:
        return '$percent%';
      case BottomBarContent.percent:
        return chapterPosition;
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
      ReaderMode.rsvp: 'RSVP',
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
            child: FocusableActionDetector(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    onModeChanged?.call(entry.key);
                    return null;
                  },
                ),
              },
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
    final progress = scrollProgress.clamp(0.0, 1.0);
    return SafeArea(
      bottom: false,
      child: Semantics(
        label: 'Прогресс чтения',
        value: '${(progress * 100).round()}%',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                ReaderColors.progressColor(theme),
              ),
            ),
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

  Future<void> _showPercentJumpDialog() async {
    final target = await showDialog<double>(
      context: context,
      builder: (context) => _PercentJumpDialog(initialPercent: (widget.value * 100).round()),
    );

    if (target != null) widget.onChanged(target / 100);
  }

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
              _CheckpointButton(
                label: 'Перейти к предыдущей закладке',
                onActivate: widget.onCheckpointBack!,
                color: widget.colors.text.withValues(alpha: 0.6),
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
            Semantics(
              button: true,
              label: 'Перейти к проценту',
              child: ExcludeSemantics(
                child: IconButton(
                  icon: const Icon(Icons.pin_drop_outlined),
                  tooltip: 'Перейти к проценту',
                  color: widget.colors.text.withValues(alpha: 0.7),
                  onPressed: _showPercentJumpDialog,
                ),
              ),
            ),
            if (widget.onCheckpointForward != null)
              _CheckpointButton(
                label: 'Перейти к следующей закладке',
                onActivate: widget.onCheckpointForward!,
                color: widget.colors.text.withValues(alpha: 0.6),
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

class _PercentJumpDialog extends StatefulWidget {
  const _PercentJumpDialog({required this.initialPercent});

  final int initialPercent;

  @override
  State<_PercentJumpDialog> createState() => _PercentJumpDialogState();
}

class _PercentJumpDialogState extends State<_PercentJumpDialog> {
  String? _error;
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPercent.toString(),
  );

  void _submit() {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      setState(() => _error = 'Введите число от 0 до 100');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Перейти к проценту'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Процент чтения',
          hintText: '0–100',
          suffixText: '%',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Перейти'),
        ),
      ],
    );
  }
}

class _CheckpointButton extends StatelessWidget {
  const _CheckpointButton({
    required this.label,
    required this.onActivate,
    required this.color,
  });

  final String label;
  final VoidCallback onActivate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: onActivate,
          icon: Icon(Icons.bookmark, size: 16, color: color),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
