import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_settings_persistence.dart';
import '../domain/reader.dart';

part 'reader_screen.g.dart';

@riverpod
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  @override
  ReaderSettings build() {
    _loadFromPrefs();
    return const ReaderSettings();
  }

  void _loadFromPrefs() {
    unawaited(
      ReaderSettingsPersistence.load().then((settings) {
        if (state == const ReaderSettings()) {
          state = settings;
        }
      }),
    );
  }

  void _persist() {
    unawaited(ReaderSettingsPersistence.save(state));
  }

  void updateTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _persist();
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
    _persist();
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
    _persist();
  }

  void updateFont(ReaderFont font) {
    state = state.copyWith(font: font);
    _persist();
  }

  void updateLineHeight(double lineHeight) {
    state = state.copyWith(lineHeight: lineHeight);
    _persist();
  }

  void updateMargin(double margin) {
    state = state.copyWith(margin: margin);
    _persist();
  }

  void updateParagraphSpacing(double spacing) {
    state = state.copyWith(paragraphSpacing: spacing);
    _persist();
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing);
    _persist();
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
    _persist();
  }

  void updateAutoThemeMode(AutoThemeMode mode) {
    state = state.copyWith(autoThemeMode: mode);
    _persist();
  }

  void updateCustomDayHour(int hour) {
    state = state.copyWith(customDayHour: hour);
    _persist();
  }

  void updateCustomNightHour(int hour) {
    state = state.copyWith(customNightHour: hour);
    _persist();
  }

  void applyProfile(ReaderSettings profile) {
    state = profile;
    _persist();
  }
}

@riverpod
class ReadingProgressNotifier extends _$ReadingProgressNotifier {
  @override
  ReadingProgress? build() {
    return null;
  }

  void updateProgress(ReadingProgress progress) {
    state = progress;
  }
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  final _autoThemeService = AutoThemeService();
  int _currentChapterIndex = 0;
  NormalizedBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _progressTimer;
  Timer? _hideTimer;
  Timer? _autoThemeTimer;
  bool _uiVisible = true;
  bool _isBottomSheetOpen = false;
  double _scrollProgress = 0.0;
  int _estimatedMinutesLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    unawaited(_loadBook());
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAutoTheme());
    _startHideTimer();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress = _scrollController.offset / maxScroll;
      setState(() {
        _scrollProgress = progress.clamp(0.0, 1.0);
      });
      _updateChapterFromScroll();
    }
  }

  void _updateChapterFromScroll() {
    if (_book == null || _book!.chapters.isEmpty) return;
    final chapterCount = _book!.chapters.length;
    final estimatedChapter = (_scrollProgress * chapterCount).floor().clamp(0, chapterCount - 1);
    if (estimatedChapter != _currentChapterIndex) {
      setState(() => _currentChapterIndex = estimatedChapter);
      ref
          .read(readingProgressProvider.notifier)
          .updateProgress(
            ReadingProgress(
              bookId: widget.bookId,
              currentPosition: estimatedChapter,
              lastRead: DateTime.now(),
            ),
          );
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isBottomSheetOpen) {
        setState(() => _uiVisible = false);
      }
    });
  }

  void _toggleUi() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) _startHideTimer();
  }

  void _checkAutoTheme() {
    if (!mounted) return;
    final settings = ref.read(readerSettingsProvider);
    if (settings.autoThemeMode == AutoThemeMode.off) return;
    final resolved = _autoThemeService.resolveTheme(
      settings.autoThemeMode,
      settings.theme,
    );
    if (resolved != settings.theme) {
      ref.read(readerSettingsProvider.notifier).updateTheme(resolved);
    }
  }

  ReaderTheme _resolveTheme(ReaderSettings settings) {
    if (settings.autoThemeMode == AutoThemeMode.off) return settings.theme;
    return _autoThemeService.resolveTheme(settings.autoThemeMode, settings.theme);
  }

  Future<void> _loadBook() async {
    try {
      final service = ref.read(bookOpenServiceProvider);
      final book = await service.openBookWithCache(widget.bookId);
      if (!mounted) return;
      final savedChapter = await _loadSavedChapterIndex();
      final totalWords = book.chapters.fold<int>(0, (sum, ch) {
        final chapterWords = ch.blocks.fold<int>(
          0,
          (bSum, block) => bSum + block.text.split(RegExp(r'\s+')).length,
        );
        return sum + chapterWords;
      });
      final wordsPerMinute = 200;
      setState(() {
        _book = book;
        _isLoading = false;
        _currentChapterIndex = savedChapter.clamp(0, book.chapters.length - 1);
        _estimatedMinutesLeft = (totalWords / wordsPerMinute).ceil();
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<int> _loadSavedChapterIndex() async {
    try {
      final db = ref.read(databaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.bookId.equals(widget.bookId))).getSingleOrNull();
      return row?.currentPosition ?? 0;
    } on Object catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saveProgress();
    }
  }

  void _saveProgress() {
    if (_book == null) return;
    final database = ref.read(databaseProvider);
    unawaited(
      database.upsertReadingProgress(
        ReadingProgressCompanion.insert(
          bookId: widget.bookId,
          currentPosition: Value(_currentChapterIndex),
          totalPages: Value(_book!.chapters.length),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final resolvedTheme = _resolveTheme(settings);
    final theme = _getThemeData(resolvedTheme);

    if (_isLoading) {
      return Theme(
        data: theme,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
      return Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(title: const Text('Читалка')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    unawaited(_loadBook());
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: theme,
      child: ReaderShortcuts(
        onNextPage: _scrollToNextChapter,
        onPreviousPage: _scrollToPreviousChapter,
        onIncreaseFontSize: () {
          final newSize = (settings.fontSize + 2.0).clamp(12.0, 32.0);
          ref.read(readerSettingsProvider.notifier).updateFontSize(newSize);
        },
        onDecreaseFontSize: () {
          final newSize = (settings.fontSize - 2.0).clamp(12.0, 32.0);
          ref.read(readerSettingsProvider.notifier).updateFontSize(newSize);
        },
        onClosePanel: () => Navigator.of(context).pop(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width < AppBreakpoints.compact) {
              return _buildPhoneReaderLayout(context, settings);
            } else if (width < AppBreakpoints.expanded) {
              return _buildTabletReaderLayout(context, settings);
            } else {
              return _buildDesktopReaderLayout(context, settings);
            }
          },
        ),
      ),
    );
  }

  void _scrollToNextChapter() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final nextOffset = currentScroll + viewportHeight * 0.8;
    unawaited(
      _scrollController.animateTo(
        nextOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _scrollToPreviousChapter() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final prevOffset = currentScroll - viewportHeight * 0.8;
    unawaited(
      _scrollController.animateTo(
        prevOffset.clamp(0.0, double.infinity),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildPhoneReaderLayout(BuildContext context, ReaderSettings settings) {
    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _buildReaderBody(context, settings),
          if (_uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(context, settings),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context, settings),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletReaderLayout(BuildContext context, ReaderSettings settings) {
    final maxWidth = 720.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding.clamp(0.0, double.infinity),
            ),
            child: _buildReaderBody(context, settings),
          ),
          if (_uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(context, settings),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(context, settings),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopReaderLayout(BuildContext context, ReaderSettings settings) {
    final maxWidth = 820.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
    final sidePanelWidth = 250.0;

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Row(
        children: [
          _buildSidePanel(context, settings, sidePanelWidth),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding.clamp(0.0, double.infinity),
                  ),
                  child: _buildReaderBody(context, settings),
                ),
                if (_uiVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(context, settings),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildBottomBar(context, settings),
                  ),
                ],
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildProgressBar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, ReaderSettings settings, double width) {
    return Container(
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Содержание'),
                Tab(text: 'Закладки'),
                Tab(text: 'Заметки'),
                Tab(text: 'Цитаты'),
              ],
              isScrollable: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTableOfContents(),
                  const Center(child: Text('Нет закладок')),
                  const Center(child: Text('Нет заметок')),
                  const Center(child: Text('Нет цитат')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableOfContents() {
    if (_book == null) return const SizedBox.shrink();
    return ListView.builder(
      itemCount: _book!.chapters.length,
      itemBuilder: (context, index) {
        final chapter = _book!.chapters[index];
        final isActive = index == _currentChapterIndex;
        return ListTile(
          title: Text(
            chapter.title.isNotEmpty ? chapter.title : 'Глава ${index + 1}',
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          dense: true,
          onTap: () {
            if (_scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              final targetOffset = (index / _book!.chapters.length) * maxScroll;
              unawaited(
                _scrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, ReaderSettings settings) {
    final colors = _getReaderColors(settings.theme);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.95),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: colors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                _book?.title ?? '',
                style: TextStyle(color: colors.text, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: colors.text),
              tooltip: 'Настройки чтения',
              onPressed: () => _showQuickSettings(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ReaderSettings settings) {
    final colors = _getReaderColors(settings.theme);
    final totalChapters = _book?.chapters.length ?? 0;
    final percentage = (_scrollProgress * 100).round();
    final remainingMinutes = (_estimatedMinutesLeft * (1 - _scrollProgress)).round();
    final hours = remainingMinutes ~/ 60;
    final mins = remainingMinutes % 60;
    // ignore: unnecessary_brace_in_string_interps — braces needed before Cyrillic chars
    final timeStr = hours > 0 ? '~${hours}ч ${mins}м' : '~${mins}м';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              colors.scaffold.withValues(alpha: 0.95),
              colors.scaffold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Глава ${_currentChapterIndex + 1} из $totalChapters',
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
                Text(
                  '$percentage%  ·  Осталось $timeStr',
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: LinearProgressIndicator(
          value: _scrollProgress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getProgressColor(),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor() {
    final theme = ref.read(readerSettingsProvider).theme;
    return switch (theme) {
      ReaderTheme.light => Colors.blue.shade700,
      ReaderTheme.paper => const Color(0xFF5B4636),
      ReaderTheme.sepia => const Color(0xFF5B4636),
      ReaderTheme.dark => Colors.blue.shade300,
      ReaderTheme.oled => Colors.blue.shade300,
      ReaderTheme.bedtime => const Color(0xFFD7CDBF),
    };
  }

  Widget _buildReaderBody(BuildContext context, ReaderSettings settings) {
    if (_book == null || _book!.chapters.isEmpty) {
      return const Center(child: Text('Нет содержимого'));
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: _handleTap,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(settings.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _book!.chapters.length; i++) ...[
                _buildChapterContent(i, settings),
                if (i < _book!.chapters.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 3),
                    child: Center(
                      child: Text(
                        '— ${_book!.chapters[i + 1].title} —',
                        style: _getReaderStyle(settings).copyWith(
                          color: _getReaderStyle(settings).color?.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;

    if (x < width / 3) {
      _scrollToPreviousChapter();
    } else if (x > width * 2 / 3) {
      _scrollToNextChapter();
    } else {
      _toggleUi();
    }
  }

  Widget _buildChapterContent(int chapterIndex, ReaderSettings settings) {
    if (_book == null || chapterIndex < 0 || chapterIndex >= _book!.chapters.length) {
      return const SizedBox.shrink();
    }

    final chapter = _book!.chapters[chapterIndex];
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chapter.title.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
            child: Text(
              chapter.title,
              style: _getReaderStyle(settings).copyWith(
                fontSize: settings.fontSize * 1.4,
                fontWeight: FontWeight.bold,
              ),
              textAlign: textAlign,
            ),
          ),
        ...chapter.blocks.map((block) => _buildBlock(block, settings, textAlign)),
      ],
    );
  }

  Widget _buildBlock(ReaderBlock block, ReaderSettings settings, TextAlign textAlign) {
    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.quote:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getReaderStyle(settings).color!.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: _getReaderStyle(settings))),
        );
      case BlockType.image:
        if (block.imageUrl != null) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Center(
              child: Icon(Icons.image, size: 64, color: _getReaderStyle(settings).color),
            ),
          );
        }
        return const SizedBox.shrink();
      case BlockType.footnote:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing / 2),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 0.85,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.paragraph:
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Text(
            block.text,
            style: _getReaderStyle(settings),
            textAlign: textAlign,
          ),
        );
    }
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    final colors = _getReaderColors(settings.theme);
    switch (settings.font) {
      case ReaderFont.sourceSerif:
        return GoogleFonts.sourceSerif4(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.literata:
        return GoogleFonts.literata(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.robotoSerif:
        return GoogleFonts.robotoSerif(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.inter:
        return GoogleFonts.inter(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: colors.text,
          letterSpacing: settings.letterSpacing,
        );
    }
  }

  _ReaderColors _getReaderColors(ReaderTheme theme) => _QuickSettingsSheet._getThemeColors(theme);

  ThemeData _getThemeData(ReaderTheme theme) {
    final base = Theme.of(context);
    final colors = _getReaderColors(theme);
    return base.copyWith(
      scaffoldBackgroundColor: colors.scaffold,
      textTheme: base.textTheme.apply(bodyColor: colors.text),
    );
  }

  void _showQuickSettings(BuildContext context) {
    _isBottomSheetOpen = true;
    _hideTimer?.cancel();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _QuickSettingsSheet(
          onDismiss: () {
            _isBottomSheetOpen = false;
            _startHideTimer();
          },
        ),
      ).whenComplete(() {
        _isBottomSheetOpen = false;
        _startHideTimer();
      }),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _scrollToPreviousChapter();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _scrollToNextChapter();
      return true;
    }
    return false;
  }
}

class _ReaderColors {
  final Color scaffold;
  final Color text;

  const _ReaderColors({required this.scaffold, required this.text});
}

class _QuickSettingsSheet extends ConsumerWidget {
  const _QuickSettingsSheet({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Тема', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildThemeRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Шрифт', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildFontRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Размер шрифта', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildFontSizeRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Межстрочный', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildLineHeightRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Отступы', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildMarginRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Авто-тема', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildAutoThemeRow(context, settings, notifier),
            const SizedBox(height: 20),

            const Text('Режим', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildModeRow(context, settings, notifier),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderTheme.values.map((theme) {
        final isSelected = settings.theme == theme;
        final colors = _getThemeColors(theme);
        return GestureDetector(
          onTap: () => notifier.updateTheme(theme),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.scaffold,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderFont.values.map((font) {
        final isSelected = settings.font == font;
        return ChoiceChip(
          label: Text(font.displayName),
          selected: isSelected,
          onSelected: (_) => notifier.updateFont(font),
        );
      }).toList(),
    );
  }

  Widget _buildFontSizeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: settings.fontSize > 12
              ? () => notifier.updateFontSize(settings.fontSize - 1)
              : null,
        ),
        Expanded(
          child: Slider(
            value: settings.fontSize,
            min: 12,
            max: 32,
            divisions: 20,
            label: '${settings.fontSize.round()}px',
            onChanged: (v) => notifier.updateFontSize(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: settings.fontSize < 32
              ? () => notifier.updateFontSize(settings.fontSize + 1)
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${settings.fontSize.round()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLineHeightRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const values = [1.3, 1.4, 1.55, 1.7, 1.9];
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = (settings.lineHeight - v).abs() < 0.01;
        return ChoiceChip(
          label: Text(v.toStringAsFixed(2)),
          selected: isSelected,
          onSelected: (_) => notifier.updateLineHeight(v),
        );
      }).toList(),
    );
  }

  Widget _buildMarginRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const values = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = (settings.margin - v).abs() < 0.5;
        return ChoiceChip(
          label: Text('${v.round()}'),
          selected: isSelected,
          onSelected: (_) => notifier.updateMargin(v),
        );
      }).toList(),
    );
  }

  Widget _buildAutoThemeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AutoThemeMode.values.map((mode) {
            final isSelected = settings.autoThemeMode == mode;
            return ChoiceChip(
              label: Text(mode.displayName),
              selected: isSelected,
              onSelected: (_) => notifier.updateAutoThemeMode(mode),
            );
          }).toList(),
        ),
        if (settings.autoThemeMode == AutoThemeMode.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('День с: ', style: TextStyle(fontSize: 13)),
              SizedBox(
                width: 50,
                child: DropdownButton<int>(
                  value: settings.customDayHour,
                  isDense: true,
                  items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
                  onChanged: (v) {
                    if (v != null) notifier.updateCustomDayHour(v);
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Text('Ночь с: ', style: TextStyle(fontSize: 13)),
              SizedBox(
                width: 50,
                child: DropdownButton<int>(
                  value: settings.customNightHour,
                  isDense: true,
                  items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
                  onChanged: (v) {
                    if (v != null) notifier.updateCustomNightHour(v);
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildModeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Прокрутка'),
            selected: settings.mode == ReaderMode.continuous,
            onSelected: (_) => notifier.updateMode(ReaderMode.continuous),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: const Text('По страницам'),
            selected: settings.mode == ReaderMode.paginated,
            onSelected: (_) => notifier.updateMode(ReaderMode.paginated),
          ),
        ),
      ],
    );
  }

  static const _ReaderColors _light = _ReaderColors(scaffold: Colors.white, text: Colors.black87);
  static const _ReaderColors _paper = _ReaderColors(
    scaffold: Color(0xFFF5F0E6),
    text: Color(0xFF3E3225),
  );
  static const _ReaderColors _sepia = _ReaderColors(
    scaffold: Color(0xFFF4ecd8),
    text: Color(0xFF5B4636),
  );
  static const _ReaderColors _dark = _ReaderColors(
    scaffold: Color(0xFF111318),
    text: Color(0xFFE6E1E5),
  );
  static const _ReaderColors _oled = _ReaderColors(scaffold: Colors.black, text: Color(0xFFDADADA));
  static const _ReaderColors _bedtime = _ReaderColors(
    scaffold: Color(0xFF1A1612),
    text: Color(0xFFD7CDBF),
  );

  static _ReaderColors _getThemeColors(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.light => _light,
      ReaderTheme.paper => _paper,
      ReaderTheme.sepia => _sepia,
      ReaderTheme.dark => _dark,
      ReaderTheme.oled => _oled,
      ReaderTheme.bedtime => _bedtime,
    };
  }
}
