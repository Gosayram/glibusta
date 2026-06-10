import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../../../shared/widgets/selection_area_wrapper.dart';
import '../data/auto_theme_service.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'reader_chrome.dart';
import 'reader_content.dart';
import 'reader_controller.dart';
import 'reader_providers.dart';
import 'reader_quick_settings.dart';
import 'reader_search_overlay.dart';
import 'reader_side_panel.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late final ReaderController _ctrl;
  double _dragStartBrightness = 0.0;
  double _dragStartY = 0.0;
  bool _fullscreenMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _ctrl = ReaderController(widget.bookId, ref);
    unawaited(_ctrl.loadBook());
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
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _ctrl.dispose();
    _ctrl.disableFullscreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    final readerState = _ctrl.state;
    final settings = ref.watch(readerSettingsProvider);
    final fullscreenMode = settings.mode == ReaderMode.fullscreen;
    if (fullscreenMode != _fullscreenMode) {
      _fullscreenMode = fullscreenMode;
      if (fullscreenMode) {
        _ctrl.enableFullscreen();
      } else {
        _ctrl.disableFullscreen();
      }
    }
    final resolvedTheme = _resolveTheme(settings);
    final theme = _getThemeData(resolvedTheme);

    if (readerState.isLoading) {
      return Theme(
        data: theme,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (readerState.errorMessage != null) {
      return Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(title: const Text('Читалка')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        readerState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (readerState.errorFilePath != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (readerState.errorFormat != null)
                                Text(
                                  'Формат: ${readerState.errorFormat}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              if (readerState.errorFileSize != null)
                                Text(
                                  'Размер: ${(readerState.errorFileSize! / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Путь: ${readerState.errorFilePath}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _ctrl.loadBook(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _ctrl.copyDiagnostics();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Диагностика скопирована')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Копировать диагностику'),
                          ),
                          if (readerState.errorFilePath != null)
                            OutlinedButton.icon(
                              onPressed: () => _showDeleteConfirmDialog(context),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text(
                                'Удалить файл',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: theme,
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
              final width = constraints.maxWidth;
              if (width < AppBreakpoints.compact) {
                return _buildPhoneLayout(context, readerState, settings);
              } else if (width < AppBreakpoints.expanded) {
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

  Widget _buildPhoneLayout(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (readerState.book != null)
            GestureDetector(
              onVerticalDragStart: settings.verticalSwipeBrightness
                  ? _handleVerticalDragStart
                  : null,
              onVerticalDragUpdate: settings.verticalSwipeBrightness
                  ? _handleVerticalDragUpdate
                  : null,
              onVerticalDragEnd: settings.verticalSwipeBrightness ? _handleVerticalDragEnd : null,
              onDoubleTap: settings.doubleTapAction != DoubleTapAction.disabled
                  ? _ctrl.handleDoubleTap
                  : null,
              onLongPress: settings.longPressAction != LongPressAction.disabled
                  ? _ctrl.handleLongPress
                  : null,
              behavior: HitTestBehavior.translucent,
              child: ReaderContentBody(
                book: readerState.book!,
                settings: settings,
                scrollController: _ctrl.scrollController,
                onTap: (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width),
                initialProgress: readerState.scrollProgress,
                initialPage: readerState.currentPosition.chapterIndex,
              ),
            ),
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
          if (_shouldShowChrome(settings, readerState)) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: readerState.book?.title ?? '',
                onBack: () => Navigator.of(context).pop(),
                onSettings: () => _showQuickSettings(context),
                onSearch: () => _ctrl.toggleSearch(),
                onMore: () {},
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ReaderBottomBar(
                settings: settings,
                currentChapterIndex: readerState.currentPosition.chapterIndex,
                totalChapters: readerState.book?.chapters.length ?? 0,
                scrollProgress: readerState.scrollProgress,
                estimatedMinutesLeft: readerState.estimatedMinutesLeft,
                onJumpToProgress: _ctrl.jumpToProgress,
              ),
            ),
          ],
          if (readerState.isSearchOpen && readerState.book != null)
            Positioned.fill(
              child: BookSearchOverlay(
                searchService: _ctrl.createSearchService()!,
                onJumpToResult: (position) {
                  _ctrl.closeSearch();
                  _ctrl.jumpToPosition(
                    position.copyWith(bookId: widget.bookId),
                  );
                },
                onDismiss: () => _ctrl.closeSearch(),
                theme: settings.theme,
              ),
            ),
        ],
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
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: readerState.book != null
                ? GestureDetector(
                    onVerticalDragStart: settings.verticalSwipeBrightness
                        ? _handleVerticalDragStart
                        : null,
                    onVerticalDragUpdate: settings.verticalSwipeBrightness
                        ? _handleVerticalDragUpdate
                        : null,
                    onVerticalDragEnd: settings.verticalSwipeBrightness
                        ? _handleVerticalDragEnd
                        : null,
                    onDoubleTap: settings.doubleTapAction != DoubleTapAction.disabled
                        ? _ctrl.handleDoubleTap
                        : null,
                    onLongPress: settings.longPressAction != LongPressAction.disabled
                        ? _ctrl.handleLongPress
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: ReaderContentBody(
                      book: readerState.book!,
                      settings: settings,
                      scrollController: _ctrl.scrollController,
                      onTap: (details) =>
                          _ctrl.handleTap(details, MediaQuery.sizeOf(context).width),
                      initialProgress: readerState.scrollProgress,
                      initialPage: readerState.currentPosition.chapterIndex,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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
          if (_shouldShowChrome(settings, readerState)) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: readerState.book?.title ?? '',
                onBack: () => Navigator.of(context).pop(),
                onSettings: () => _showQuickSettings(context),
                onSearch: () => _ctrl.toggleSearch(),
                onMore: () {},
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ReaderBottomBar(
                settings: settings,
                currentChapterIndex: readerState.currentPosition.chapterIndex,
                totalChapters: readerState.book?.chapters.length ?? 0,
                scrollProgress: readerState.scrollProgress,
                estimatedMinutesLeft: readerState.estimatedMinutesLeft,
                onJumpToProgress: _ctrl.jumpToProgress,
              ),
            ),
          ],
          if (readerState.isSearchOpen && readerState.book != null)
            Positioned.fill(
              child: BookSearchOverlay(
                searchService: _ctrl.createSearchService()!,
                onJumpToResult: (position) {
                  _ctrl.closeSearch();
                  _ctrl.jumpToPosition(
                    position.copyWith(bookId: widget.bookId),
                  );
                },
                onDismiss: () => _ctrl.closeSearch(),
                theme: settings.theme,
              ),
            ),
        ],
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
          if (readerState.book != null)
            ReaderSidePanel(
              book: readerState.book!,
              currentChapterIndex: readerState.currentPosition.chapterIndex,
              scrollController: _ctrl.scrollController,
              width: sidePanelWidth,
              onJumpToPosition: _ctrl.jumpToPosition,
            ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: effectiveWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: readerState.book != null
                      ? SelectionAreaWrapper(
                          child: GestureDetector(
                            onVerticalDragStart: settings.verticalSwipeBrightness
                                ? _handleVerticalDragStart
                                : null,
                            onVerticalDragUpdate: settings.verticalSwipeBrightness
                                ? _handleVerticalDragUpdate
                                : null,
                            onVerticalDragEnd: settings.verticalSwipeBrightness
                                ? _handleVerticalDragEnd
                                : null,
                            onDoubleTap: settings.doubleTapAction != DoubleTapAction.disabled
                                ? _ctrl.handleDoubleTap
                                : null,
                            onLongPress: settings.longPressAction != LongPressAction.disabled
                                ? _ctrl.handleLongPress
                                : null,
                            behavior: HitTestBehavior.translucent,
                            child: ReaderContentBody(
                              book: readerState.book!,
                              settings: settings,
                              scrollController: _ctrl.scrollController,
                              onTap: (details) => _ctrl.handleTap(
                                details,
                                MediaQuery.sizeOf(context).width,
                              ),
                              initialProgress: readerState.scrollProgress,
                              initialPage: readerState.currentPosition.chapterIndex,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
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
                if (_shouldShowChrome(settings, readerState)) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ReaderTopBar(
                      settings: settings,
                      bookTitle: readerState.book?.title ?? '',
                      onBack: () => Navigator.of(context).pop(),
                      onSettings: () => _showQuickSettings(context),
                      onSearch: () => _ctrl.toggleSearch(),
                      onMore: () {},
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ReaderBottomBar(
                      settings: settings,
                      currentChapterIndex: readerState.currentPosition.chapterIndex,
                      totalChapters: readerState.book?.chapters.length ?? 0,
                      scrollProgress: readerState.scrollProgress,
                      estimatedMinutesLeft: readerState.estimatedMinutesLeft,
                    ),
                  ),
                ],
                if (readerState.isSearchOpen && readerState.book != null)
                  Positioned.fill(
                    child: BookSearchOverlay(
                      searchService: _ctrl.createSearchService()!,
                      onJumpToResult: (position) {
                        _ctrl.closeSearch();
                        _ctrl.jumpToPosition(
                          position.copyWith(bookId: widget.bookId),
                        );
                      },
                      onDismiss: () => _ctrl.closeSearch(),
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
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReaderQuickSettingsSheet(
          onDismiss: () => _ctrl.onBottomSheetClose(),
        ),
      ).whenComplete(() => _ctrl.onBottomSheetClose()),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить файл?'),
          content: const Text(
            'Файл книги будет удалён с устройства. '
            'Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                unawaited(_ctrl.deleteBookFile());
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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

  bool _shouldShowChrome(ReaderSettings settings, ReaderState readerState) {
    if (_isDistractionFree(settings)) return false;
    return readerState.uiVisible;
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
