import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/adaptive_context.dart';
import '../../../core/theme/app_duration.dart';
import '../../../shared/widgets/adaptive_panel.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../../../shared/widgets/selection_area_wrapper.dart';
import '../../library/data/book_delete_service.dart';
import '../data/auto_theme_service.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'reader_chrome.dart';
import 'reader_content.dart';
import 'reader_context_menu.dart';
import 'reader_controller.dart';
import 'reader_error_panel.dart';
import 'reader_gesture_coordinator.dart';
import 'reader_providers.dart';
import 'reader_quick_settings.dart';
import 'reader_search_overlay.dart';
import 'reader_selection_toolbar.dart';
import 'reader_side_panel.dart';
import 'table_of_contents_sheet.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final ReaderController _ctrl;
  final _gestureCoordinator = ReaderGestureCoordinator();
  AppLifecycleListener? _lifecycleListener;
  double _dragStartBrightness = 0.0;
  double _dragStartY = 0.0;
  bool _fullscreenMode = false;
  String? _selectedText;

  Future<void> _checkForSelectedText() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted && data?.text != null && data!.text!.isNotEmpty && data.text != _selectedText) {
      setState(() => _selectedText = data.text);
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleState,
    );
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _ctrl = ref.read(readerControllerProvider(widget.bookId));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFullscreen(ref.read(readerSettingsProvider).mode);
      ref.listenManual(readerSettingsProvider, (prev, next) {
        _syncFullscreen(next.mode);
        if (prev != null) _handleLayoutChange(prev, next);
      });
    });
  }

  void _syncFullscreen(ReaderMode mode) {
    final isFullscreen = mode == ReaderMode.fullscreen;
    if (isFullscreen == _fullscreenMode) return;
    _fullscreenMode = isFullscreen;
    if (isFullscreen) {
      _ctrl.enableFullscreen();
    } else {
      _ctrl.disableFullscreen();
    }
  }

  void _handleLayoutChange(ReaderSettings prev, ReaderSettings next) {
    final layoutChanged =
        prev.fontSize != next.fontSize ||
        prev.lineHeight != next.lineHeight ||
        prev.margin != next.margin ||
        prev.paragraphSpacing != next.paragraphSpacing ||
        prev.letterSpacing != next.letterSpacing ||
        prev.textAlign != next.textAlign ||
        prev.font != next.font ||
        prev.paragraphFirstLineIndent != next.paragraphFirstLineIndent ||
        prev.readerWidth != next.readerWidth ||
        prev.hyphenation != next.hyphenation;
    if (layoutChanged) {
      _ctrl.reanchorAfterLayoutChange();
    }
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    final settings = ref.read(readerSettingsProvider);
    if (!settings.verticalSwipeBrightness) return;
    _dragStartBrightness = settings.brightness;
    _dragStartY = details.globalPosition.dy;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final settings = ref.read(readerSettingsProvider);
    if (!settings.verticalSwipeBrightness) return;
    final deltaY = details.globalPosition.dy - _dragStartY;
    final brightnessChange = -deltaY / 500.0;
    final newBrightness = (_dragStartBrightness + brightnessChange).clamp(0.2, 1.0);
    ref.read(readerSettingsProvider.notifier).updateBrightness(newBrightness);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    // Nothing needed
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _ctrl.saveProgress();
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _ctrl.scrollToPrevious();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _ctrl.scrollToNext();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readerControllerProvider(widget.bookId));
    return StreamBuilder<ReaderState>(
      stream: _ctrl.stateStream,
      initialData: _ctrl.state,
      builder: (context, snapshot) {
        return _buildForState(context, snapshot.data ?? _ctrl.state);
      },
    );
  }

  Widget _buildForState(BuildContext context, ReaderState readerState) {
    final settings = ref.watch(readerSettingsProvider);
    final resolvedTheme = _resolveTheme(settings);
    final theme = _getThemeData(resolvedTheme);

    if (readerState.isLoading) {
      return AnimatedTheme(
        data: theme,
        duration: AppDuration.readerThemeTransition,
        curve: Curves.easeOutCubic,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (readerState.loadingMessage != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    readerState.loadingMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  if (readerState.isDynamicallyLoading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (readerState.errorMessage != null) {
      return ReaderErrorPanel(
        controller: _ctrl,
        readerState: readerState,
        bookId: widget.bookId,
        onDeleteFile: () => _showDeleteConfirmDialog(context),
        onDeleteFromLibrary: () async {
          final svc = ref.read(bookDeleteServiceProvider);
          await svc.removeFromLibrary(widget.bookId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Удалено из библиотеки')),
          );
          if (context.mounted) Navigator.of(context).pop();
        },
      );
    }

    if (!readerState.isLoading && readerState.metadata != null && readerState.chapterCount == 0) {
      return AnimatedTheme(
        data: theme,
        duration: AppDuration.readerThemeTransition,
        curve: Curves.easeOutCubic,
        child: Scaffold(
          appBar: AppBar(title: const Text('Читалка')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Книга не содержит глав',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Содержимое не удалось разобрать или файл повреждён.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedTheme(
      data: theme,
      duration: AppDuration.readerThemeTransition,
      curve: Curves.easeOutCubic,
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _ctrl.saveProgress();
        },
        child: ReaderShortcuts(
          onNextPage: () => _ctrl.scrollToNext(),
          onPreviousPage: () => _ctrl.scrollToPrevious(),
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
              final wc = windowClassOf(context);
              if (wc == WindowClass.compact) {
                return _buildPhoneLayout(context, readerState, settings);
              } else if (wc == WindowClass.medium) {
                return _buildTabletLayout(context, readerState, settings);
              } else {
                return _buildDesktopLayout(context, readerState, settings);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReaderContentStack(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings, {
    required Widget content,
  }) {
    return Stack(
      children: [
        content,
        _buildWarmthOverlay(settings),
        _buildBrightnessOverlay(settings),
        if (_shouldShowProgressBar(settings, readerState))
          Positioned(
            top: settings.progressBarPosition == ProgressBarPosition.top ? 0 : null,
            bottom: settings.progressBarPosition == ProgressBarPosition.bottom ? 0 : null,
            left: 0,
            right: 0,
            child: ReaderProgressBar(
              scrollProgress: readerState.scrollProgress,
              theme: settings.theme,
            ),
          ),
        if (!_isDistractionFree(settings)) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: readerState.uiVisible ? Offset.zero : const Offset(0, -1),
              duration: AppDuration.fast,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: readerState.uiVisible ? 1.0 : 0.0,
                duration: AppDuration.fast,
                child: ReaderTopBar(
                  settings: settings,
                  bookTitle: readerState.metadata?.title ?? '',
                  onBack: () => Navigator.of(context).pop(),
                  onSettings: () => _showQuickSettings(context),
                  onSearch: () {
                    _ctrl.toggleSearch();
                    if (_ctrl.state.isSearchOpen) {
                      _gestureCoordinator.onSearchOpened();
                    } else {
                      _gestureCoordinator.onSearchClosed();
                    }
                  },
                  onMore: readerState.metadata != null
                      ? () => TableOfContentsSheet.show(
                          context,
                          metadata: readerState.metadata!,
                          currentChapterIndex: readerState.currentPosition.chapterIndex,
                          onJumpToPosition: _ctrl.jumpToPosition,
                          loadedChapters: readerState.loadedChapters,
                          isDynamicallyLoading: readerState.isDynamicallyLoading,
                        )
                      : () {},
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: readerState.uiVisible ? Offset.zero : const Offset(0, 1),
              duration: AppDuration.fast,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: readerState.uiVisible ? 1.0 : 0.0,
                duration: AppDuration.fast,
                child: ReaderBottomBar(
                  settings: settings,
                  currentChapterIndex: readerState.currentPosition.chapterIndex,
                  totalChapters: readerState.chapterCount,
                  scrollProgress: readerState.scrollProgress,
                  estimatedMinutesLeft: readerState.estimatedMinutesLeft,
                  onJumpToProgress: _ctrl.jumpToProgress,
                ),
              ),
            ),
          ),
        ],
        if (readerState.isSearchOpen && readerState.metadata != null)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final searchService = _ctrl.createSearchService();
                if (searchService == null) return const SizedBox.shrink();
                return BookSearchOverlay(
                  searchService: searchService,
                  onJumpToResult: (position, query) {
                    _ctrl.closeSearch();
                    _ctrl.highlightSearchQuery(query);
                    _ctrl.jumpToPosition(
                      position.copyWith(bookId: widget.bookId),
                    );
                  },
                  onDismiss: () {
                    _ctrl.closeSearch();
                    _gestureCoordinator.onSearchClosed();
                  },
                  theme: settings.theme,
                );
              },
            ),
          ),
        if (_selectedText != null && _selectedText!.isNotEmpty && readerState.metadata != null)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 80,
            left: 24,
            right: 24,
            child: ReaderSelectionToolbar(
              bookId: widget.bookId,
              chapterIndex: readerState.currentPosition.chapterIndex,
              paragraphIndex: readerState.currentPosition.paragraphIndex,
              onDismiss: () => setState(() => _selectedText = null),
            ),
          ),
      ],
    );
  }

  Widget _buildGestureWrappedContent(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    if (readerState.metadata == null) return const SizedBox.shrink();
    return SelectionAreaWrapper(
      contextMenuBuilder: (BuildContext context, SelectableRegionState state) {
        return ReaderContextMenu(
          state: state,
          bookId: widget.bookId,
          chapterIndex: readerState.currentPosition.chapterIndex,
          paragraphIndex: readerState.currentPosition.paragraphIndex,
        );
      },
      child: GestureDetector(
        onVerticalDragStart:
            _gestureCoordinator.shouldHandleVerticalDrag && settings.verticalSwipeBrightness
            ? _handleVerticalDragStart
            : null,
        onVerticalDragUpdate:
            _gestureCoordinator.shouldHandleVerticalDrag && settings.verticalSwipeBrightness
            ? _handleVerticalDragUpdate
            : null,
        onVerticalDragEnd:
            _gestureCoordinator.shouldHandleVerticalDrag && settings.verticalSwipeBrightness
            ? _handleVerticalDragEnd
            : null,
        onDoubleTap:
            _gestureCoordinator.shouldHandleDoubleTap &&
                settings.doubleTapAction != DoubleTapAction.disabled
            ? _ctrl.handleDoubleTap
            : null,
        onLongPress:
            _gestureCoordinator.shouldHandleLongPress &&
                settings.longPressAction != LongPressAction.disabled
            ? () {
                _ctrl.handleLongPress();
                if (settings.longPressAction == LongPressAction.selectText) {
                  unawaited(_checkForSelectedText());
                }
              }
            : null,
        behavior: HitTestBehavior.translucent,
        child: RepaintBoundary(
          child: ReaderContentBody(
            metadata: readerState.metadata!,
            loadedChapters: readerState.loadedChapters,
            settings: settings,
            scrollController: _ctrl.scrollController,
            onTap: _gestureCoordinator.shouldHandleTap
                ? (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width)
                : (_) {},
            initialProgress: readerState.scrollProgress,
            initialPage: readerState.currentPosition.chapterIndex,
            highlightQuery: readerState.highlightedQuery,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final maxContentWidth = isLandscape ? 720.0 : double.infinity;
    final horizontalPadding = isLandscape
        ? ((screenWidth - maxContentWidth) / 2).clamp(16.0, 48.0)
        : 0.0;

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: _buildReaderContentStack(
        context,
        readerState,
        settings,
        content: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildGestureWrappedContent(context, readerState, settings),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxContentWidth = screenWidth > 640 ? 720.0 : screenWidth - 32.0;
    final effectiveWidth = settings.readerWidth.clamp(600.0, maxContentWidth);
    final horizontalPadding = ((screenWidth - effectiveWidth) / 2).clamp(16.0, 48.0);

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: _buildReaderContentStack(
        context,
        readerState,
        settings,
        content: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: _buildGestureWrappedContent(context, readerState, settings),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    const sidePanelWidth = 250.0;
    final availableWidth = screenWidth - sidePanelWidth - 1.0;
    final maxContentWidth = (availableWidth - 32.0).clamp(600.0, availableWidth);
    final effectiveWidth = settings.readerWidth.clamp(600.0, maxContentWidth);
    final horizontalPadding = ((availableWidth - effectiveWidth) / 2).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (readerState.metadata != null)
            ReaderSidePanel(
              metadata: readerState.metadata!,
              currentChapterIndex: readerState.currentPosition.chapterIndex,
              scrollController: _ctrl.scrollController,
              width: sidePanelWidth,
              onJumpToPosition: _ctrl.jumpToPosition,
            ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _buildReaderContentStack(
              context,
              readerState,
              settings,
              content: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildGestureWrappedContent(context, readerState, settings),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ReaderTheme _resolveTheme(ReaderSettings settings) {
    if (settings.autoThemeMode != AutoThemeMode.off) {
      return AutoThemeService().resolveTheme(
        settings.autoThemeMode,
        settings.theme,
      );
    }
    if (settings.theme == ReaderTheme.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? ReaderTheme.dark
          : ReaderTheme.light;
    }
    return settings.theme;
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
    _ctrl.onBottomSheetOpen();
    _gestureCoordinator.onBottomSheetOpened();
    unawaited(
      showAdaptivePanel<void>(
        context: context,
        child: ReaderQuickSettingsSheet(
          onDismiss: () {
            _ctrl.onBottomSheetClose();
            _gestureCoordinator.onBottomSheetClosed();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    final rootContext = context;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Удалить файл?'),
          content: const Text(
            'Файл книги будет удалён с устройства. '
            'Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                _ctrl.saveProgress();
                Navigator.of(dialogContext).pop();
                await _ctrl.deleteBookFile();
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Файл удалён')),
                  );
                }
                if (rootContext.mounted && Navigator.of(rootContext).canPop()) {
                  Navigator.of(rootContext).pop();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowProgressBar(ReaderSettings settings, ReaderState readerState) {
    if (settings.progressBarPosition == ProgressBarPosition.hidden) return false;
    if (_isDistractionFree(settings)) return false;
    return readerState.scrollProgress > 0;
  }

  bool _isDistractionFree(ReaderSettings settings) {
    return settings.mode == ReaderMode.focus || settings.mode == ReaderMode.fullscreen;
  }

  Widget _buildWarmthOverlay(ReaderSettings settings) {
    if (settings.warmth <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Color.fromRGBO(255, 140, 0, settings.warmth * 0.25),
        ),
      ),
    );
  }

  Widget _buildBrightnessOverlay(ReaderSettings settings) {
    if (settings.brightness >= 1.0) return const SizedBox.shrink();
    final dimAlpha = (1.0 - settings.brightness) * 0.5;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Color.fromRGBO(0, 0, 0, dimAlpha),
        ),
      ),
    );
  }
}
