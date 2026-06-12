import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/platform/adaptive_context.dart';
import '../../../core/theme/app_duration.dart';
import '../../../shared/widgets/adaptive_panel.dart';
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
    _ctrl = ReaderController(widget.bookId, ref);
    unawaited(_ctrl.loadBook());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFullscreen(ref.read(readerSettingsProvider).mode);
      ref.listenManual(readerSettingsProvider, (prev, next) {
        _syncFullscreen(next.mode);
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
    _ctrl.disableFullscreen();
    _ctrl.dispose();
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
    final readerState = _ctrl.state;
    final settings = ref.watch(readerSettingsProvider);
    final resolvedTheme = _resolveTheme(settings);
    final theme = _getThemeData(resolvedTheme);

    if (readerState.isLoading) {
      return AnimatedTheme(
        data: theme,
        duration: AppDuration.readerThemeTransition,
        curve: Curves.easeOutCubic,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (readerState.errorMessage != null) {
      return AnimatedTheme(
        data: theme,
        duration: AppDuration.readerThemeTransition,
        curve: Curves.easeOutCubic,
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
                  onSearch: () => _ctrl.toggleSearch(),
                  onMore: readerState.metadata != null
                      ? () => TableOfContentsSheet.show(
                          context,
                          metadata: readerState.metadata!,
                          currentChapterIndex: readerState.currentPosition.chapterIndex,
                          onJumpToPosition: _ctrl.jumpToPosition,
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
                  onDismiss: () => _ctrl.closeSearch(),
                  theme: settings.theme,
                );
              },
            ),
          ),
        if (_selectedText != null && _selectedText!.isNotEmpty && readerState.metadata != null)
          Positioned(
            bottom: 80,
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
        return _ReaderContextMenu(
          state: state,
          bookId: widget.bookId,
          chapterIndex: readerState.currentPosition.chapterIndex,
          paragraphIndex: readerState.currentPosition.paragraphIndex,
        );
      },
      child: GestureDetector(
        onVerticalDragStart: settings.verticalSwipeBrightness ? _handleVerticalDragStart : null,
        onVerticalDragUpdate: settings.verticalSwipeBrightness ? _handleVerticalDragUpdate : null,
        onVerticalDragEnd: settings.verticalSwipeBrightness ? _handleVerticalDragEnd : null,
        onDoubleTap: settings.doubleTapAction != DoubleTapAction.disabled
            ? _ctrl.handleDoubleTap
            : null,
        onLongPress: settings.longPressAction != LongPressAction.disabled
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
            onTap: (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width),
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
    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: _buildReaderContentStack(
        context,
        readerState,
        settings,
        content: _buildGestureWrappedContent(context, readerState, settings),
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
    unawaited(
      showAdaptivePanel<void>(
        context: context,
        child: ReaderQuickSettingsSheet(
          onDismiss: () {
            _ctrl.onBottomSheetClose();
            Navigator.of(context).pop();
          },
        ),
      ),
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
              onPressed: () async {
                _ctrl.saveProgress();
                Navigator.of(context).pop();
                try {
                  await _ctrl.deleteBookFile();
                } on Object catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Не удалось удалить: $e')),
                    );
                  }
                }
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
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

class _ReaderContextMenu extends StatelessWidget {
  final SelectableRegionState state;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;

  const _ReaderContextMenu({
    required this.state,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
  });

  @override
  Widget build(BuildContext context) {
    final selectedText = _getSelectedText();
    if (selectedText.isEmpty) return const SizedBox.shrink();

    final buttonItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
        },
        label: 'Копировать',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveQuote(context, selectedText));
        },
        label: 'Цитата',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveBookmark(context, selectedText));
        },
        label: 'Закладка',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          state.hideToolbar(false);
          unawaited(_saveNote(context, selectedText));
        },
        label: 'Заметка',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  String _getSelectedText() {
    // ignore: deprecated_member_use
    final selection = state.textEditingValue.selection;
    if (!selection.isCollapsed) {
      // ignore: deprecated_member_use
      return selection.textInside(state.textEditingValue.text);
    }
    return '';
  }

  Future<void> _saveQuote(BuildContext context, String text) async {
    if (!context.mounted) return;
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Цитата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Комментарий (необязательно)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      try {
        final db = ProviderScope.containerOf(context).read(databaseProvider);
        await db
            .into(db.quotes)
            .insert(
              QuotesCompanion.insert(
                id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                selectedText: text,
                note: Value(result.isEmpty ? null : result),
              ),
            );
        AppLogger().fine('quote saved for chapter $chapterIndex', name: 'Reader');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Цитата сохранена')),
          );
        }
      } on Object catch (e) {
        AppLogger().warning('Failed to save quote: $e', name: 'Reader', error: e);
      }
    }
  }

  Future<void> _saveBookmark(BuildContext context, String text) async {
    if (!context.mounted) return;
    try {
      final db = ProviderScope.containerOf(context).read(databaseProvider);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
              bookId: bookId,
              chapterIndex: chapterIndex,
              paragraphIndex: paragraphIndex,
              selectedText: Value(text),
            ),
          );
      AppLogger().fine('bookmark saved for chapter $chapterIndex', name: 'Reader');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Закладка сохранена')),
        );
      }
    } on Object catch (e) {
      AppLogger().warning('Failed to save bookmark: $e', name: 'Reader', error: e);
    }
  }

  Future<void> _saveNote(BuildContext context, String text) async {
    if (!context.mounted) return;
    final textController = TextEditingController(text: text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Введите заметку...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      try {
        final db = ProviderScope.containerOf(context).read(databaseProvider);
        await db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: '$bookId-${DateTime.now().millisecondsSinceEpoch}',
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                content: result,
              ),
            );
        AppLogger().fine('note saved for chapter $chapterIndex', name: 'Reader');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заметка сохранена')),
          );
        }
      } on Object catch (e) {
        AppLogger().warning('Failed to save note: $e', name: 'Reader', error: e);
      }
    }
  }
}
