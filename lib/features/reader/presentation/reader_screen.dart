import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'reader_chrome.dart';
import 'reader_content.dart';
import 'reader_providers.dart';
import 'reader_quick_settings.dart';
import 'reader_side_panel.dart';

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
    _progressTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveProgress(),
    );
    _autoThemeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAutoTheme(),
    );
    _startHideTimer();
    unawaited(WakelockPlus.enable());
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
    return _autoThemeService.resolveTheme(
      settings.autoThemeMode,
      settings.theme,
    );
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
      const wordsPerMinute = 200;
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
    unawaited(WakelockPlus.disable());
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
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _saveProgress();
          }
        },
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

  Widget _buildPhoneReaderLayout(
    BuildContext context,
    ReaderSettings settings,
  ) {
    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (_book != null)
            ReaderContentBody(
              book: _book!,
              settings: settings,
              scrollController: _scrollController,
              onTap: _handleTap,
            ),
          if (_uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: _book?.title ?? '',
                onBack: () => Navigator.of(context).pop(),
                onSettings: () => _showQuickSettings(context),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ReaderBottomBar(
                settings: settings,
                currentChapterIndex: _currentChapterIndex,
                totalChapters: _book?.chapters.length ?? 0,
                scrollProgress: _scrollProgress,
                estimatedMinutesLeft: _estimatedMinutesLeft,
              ),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderProgressBar(
              scrollProgress: _scrollProgress,
              theme: settings.theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletReaderLayout(
    BuildContext context,
    ReaderSettings settings,
  ) {
    const maxWidth = 720.0;
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
            child: _book != null
                ? ReaderContentBody(
                    book: _book!,
                    settings: settings,
                    scrollController: _scrollController,
                    onTap: _handleTap,
                  )
                : const SizedBox.shrink(),
          ),
          if (_uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: _book?.title ?? '',
                onBack: () => Navigator.of(context).pop(),
                onSettings: () => _showQuickSettings(context),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ReaderBottomBar(
                settings: settings,
                currentChapterIndex: _currentChapterIndex,
                totalChapters: _book?.chapters.length ?? 0,
                scrollProgress: _scrollProgress,
                estimatedMinutesLeft: _estimatedMinutesLeft,
              ),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderProgressBar(
              scrollProgress: _scrollProgress,
              theme: settings.theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopReaderLayout(
    BuildContext context,
    ReaderSettings settings,
  ) {
    const maxWidth = 820.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
    const sidePanelWidth = 250.0;

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (_book != null)
            ReaderSidePanel(
              book: _book!,
              currentChapterIndex: _currentChapterIndex,
              scrollController: _scrollController,
              width: sidePanelWidth,
            ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding.clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: _book != null
                      ? ReaderContentBody(
                          book: _book!,
                          settings: settings,
                          scrollController: _scrollController,
                          onTap: _handleTap,
                        )
                      : const SizedBox.shrink(),
                ),
                if (_uiVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ReaderTopBar(
                      settings: settings,
                      bookTitle: _book?.title ?? '',
                      onBack: () => Navigator.of(context).pop(),
                      onSettings: () => _showQuickSettings(context),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ReaderBottomBar(
                      settings: settings,
                      currentChapterIndex: _currentChapterIndex,
                      totalChapters: _book?.chapters.length ?? 0,
                      scrollProgress: _scrollProgress,
                      estimatedMinutesLeft: _estimatedMinutesLeft,
                    ),
                  ),
                ],
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReaderProgressBar(
                    scrollProgress: _scrollProgress,
                    theme: settings.theme,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  ThemeData _getThemeData(ReaderTheme theme) {
    final base = Theme.of(context);
    final colors = ReaderColors.forTheme(theme);
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
        builder: (context) => ReaderQuickSettingsSheet(
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
