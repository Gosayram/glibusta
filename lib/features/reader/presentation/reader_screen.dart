import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';

import '../../../core/theme/app_duration.dart';
import '../../../shared/widgets/adaptive_panel.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../../../shared/widgets/selection_area_wrapper.dart';
import '../../highlights/presentation/highlight_providers.dart';
import '../../library/data/book_delete_service.dart';
import '../data/reader_colors.dart';
import '../data/reading_info_model.dart';
import '../domain/reader.dart';
import 'color_preset_provider.dart';
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
import 'reading_info_provider.dart';
import 'table_of_contents_sheet.dart';

enum _ReadingInfoPosition { header, footer }

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
  bool _dragStartedInTopZone = false;
  bool _dragStartedInLeftHalf = false;
  double _dragStartFontSize = 0.0;
  String? _selectedText;
  int _batteryLevel = -1;

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
    unawaited(_fetchBatteryLevel());
    _enterImmersiveMode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(readerSettingsProvider, (prev, next) {
        if (prev != null) _handleLayoutChange(prev, next);
        if (prev == null || prev.orientationLock != next.orientationLock) {
          _syncOrientation(next.orientationLock);
        }
      });
    });
  }

  void _syncOrientation(OrientationLock lock) {
    final orientations = switch (lock) {
      OrientationLock.none => null,
      OrientationLock.portrait => [DeviceOrientation.portraitUp],
      OrientationLock.landscape => [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    };
    unawaited(
      SystemChrome.setPreferredOrientations(orientations ?? []),
    );
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
    final screenSize = MediaQuery.sizeOf(context);
    _dragStartedInTopZone = details.globalPosition.dy < screenSize.height * 0.1;
    _dragStartedInLeftHalf = details.globalPosition.dx < screenSize.width / 2;
    if (!settings.verticalSwipeBrightness) return;
    _dragStartBrightness = settings.brightness;
    _dragStartFontSize = settings.fontSize;
    _dragStartY = details.globalPosition.dy;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final settings = ref.read(readerSettingsProvider);
    if (!settings.verticalSwipeBrightness) return;
    final deltaY = details.globalPosition.dy - _dragStartY;
    if (_dragStartedInLeftHalf) {
      final brightnessChange = -deltaY / 500.0;
      final newBrightness = (_dragStartBrightness + brightnessChange).clamp(0.2, 1.0);
      ref.read(readerSettingsProvider.notifier).updateBrightness(newBrightness);
    } else {
      final fontChange = -deltaY / 200.0;
      final newFontSize = (_dragStartFontSize + fontChange).clamp(10.0, 32.0);
      ref.read(readerSettingsProvider.notifier).updateFontSize(newFontSize);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_dragStartedInTopZone && details.primaryVelocity != null && details.primaryVelocity! > 300) {
      Navigator.of(context).pop();
    }
  }

  // Trackpad/mouse wheel scroll → page turn
  double _scrollAccumulator = 0;
  static const double _scrollThreshold = 50;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _scrollAccumulator += event.scrollDelta.dy;
      if (_scrollAccumulator.abs() >= _scrollThreshold) {
        if (_scrollAccumulator > 0) {
          _goToNextPage();
        } else {
          _goToPreviousPage();
        }
        _scrollAccumulator = 0;
      }
    }
  }

  // Horizontal swipe for page turns
  double _dragStartX = 0;
  bool _isHorizontalDrag = false;

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    _isHorizontalDrag = false;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final deltaX = details.globalPosition.dx - _dragStartX;
    if (deltaX.abs() > 20) {
      _isHorizontalDrag = true;
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_isHorizontalDrag) return;
    final settings = ref.read(readerSettingsProvider);
    final sensitivity = switch (settings.horizontalGestureScroll) {
      HorizontalGestureScroll.half => 0.5,
      HorizontalGestureScroll.twoThirds => 0.67,
      HorizontalGestureScroll.threeQuarters => 0.75,
    };
    final screenWidth = MediaQuery.sizeOf(context).width;
    final threshold = screenWidth * sensitivity;
    final deltaX = details.globalPosition.dx - _dragStartX;
    final velocity = details.primaryVelocity ?? 0;

    if (deltaX.abs() > threshold || velocity.abs() > 500) {
      final isForward = deltaX < 0 || velocity < 0;
      final isInverted = settings.horizontalGesture == HorizontalGesture.inverse;
      if (isForward != isInverted) {
        _goToNextPage();
      } else {
        _goToPreviousPage();
      }
    }
  }

  void _goToNextPage() {
    unawaited(HapticFeedback.lightImpact());
    _ctrl.scrollToNext();
  }

  void _goToPreviousPage() {
    unawaited(HapticFeedback.lightImpact());
    _ctrl.scrollToPrevious();
  }

  void _handleLinkTap(String href, ReaderState readerState) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      _showExternalLinkDialog(href);
      return;
    }
    final anchor = href.startsWith('#') ? href.substring(1) : href;
    if (anchor.isEmpty) return;

    final chapterIndex = readerState.currentPosition.chapterIndex;
    final chapter = readerState.loadedChapters[chapterIndex];
    if (chapter == null) return;

    for (int i = 0; i < chapter.blocks.length; i++) {
      final block = chapter.blocks[i];
      if (block.noteId == anchor) {
        _ctrl.pushLinkPosition();
        _ctrl.jumpToPosition(
          readerState.currentPosition.copyWith(
            bookId: widget.bookId,
            chapterIndex: chapterIndex,
            paragraphIndex: i,
          ),
        );
        return;
      }
    }

    unawaited(HapticFeedback.selectionClick());
  }

  void _showExternalLinkDialog(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    final host = uri.host.isNotEmpty ? uri.host : href;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Внешняя ссылка'),
          content: Text('Открыть ссылку?\n$host'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
              },
              child: const Text('Открыть'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exitImmersiveMode();
    _lifecycleListener?.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    unawaited(SystemChrome.setPreferredOrientations([]));
    super.dispose();
  }

  void _enterImmersiveMode() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    }
  }

  void _exitImmersiveMode() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _ctrl.pauseSession();
      _ctrl.saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      _ctrl.resumeSession();
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _goToPreviousPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _goToNextPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _goToPreviousPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _goToNextPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _goToPreviousPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _goToNextPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _goToNextPage();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
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
    final theme = _getThemeData(settings);

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
          unawaited(SmartDialog.showToast('Удалено из библиотеки'));
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
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_ctrl.popLinkPosition()) return;
          _ctrl.saveProgress();
          Navigator.of(context).pop();
        },
        child: ReaderShortcuts(
          onNextPage: () => _goToNextPage(),
          onPreviousPage: () => _goToPreviousPage(),
          onIncreaseFontSize: () {
            final newSize = (settings.fontSize + 2.0).clamp(10.0, 40.0);
            ref.read(readerSettingsProvider.notifier).updateFontSize(newSize);
          },
          onDecreaseFontSize: () {
            final newSize = (settings.fontSize - 2.0).clamp(10.0, 40.0);
            ref.read(readerSettingsProvider.notifier).updateFontSize(newSize);
          },
          onClosePanel: () {
            if (_ctrl.popLinkPosition()) return;
            Navigator.of(context).pop();
          },
          child: _buildReaderLayout(context, readerState, settings),
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
        if (settings.scrollbarIndicator && settings.mode == ReaderMode.continuous)
          Positioned(
            right: 2,
            top: 48,
            bottom: 60,
            child: _ScrollbarIndicator(progress: readerState.scrollProgress),
          ),
        Positioned(
          left: 48,
          right: 48,
          top: 48,
          height: 48,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              _cycleColorPreset(v > 0 ? 1 : -1);
            },
          ),
        ),
        _buildReadingInfoBar(
          context,
          readerState,
          settings,
          position: _ReadingInfoPosition.header,
        ),
        _buildReadingInfoBar(
          context,
          readerState,
          settings,
          position: _ReadingInfoPosition.footer,
        ),
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
                bookAuthor: readerState.metadata?.authors.join(', '),
                isBookmarked: readerState.checkpoints.any(
                  (c) => (c - readerState.scrollProgress).abs() < 0.02,
                ),
                onBack: () {
                  if (_ctrl.popLinkPosition()) return;
                  Navigator.of(context).pop();
                },
                onSearch: () {
                  _ctrl.toggleSearch();
                  if (_ctrl.state.isSearchOpen) {
                    _gestureCoordinator.onSearchOpened();
                  } else {
                    _gestureCoordinator.onSearchClosed();
                  }
                },
                onToc: readerState.metadata != null
                    ? () {
                        _ctrl.saveCheckpoint();
                        TableOfContentsSheet.show(
                          context,
                          metadata: readerState.metadata!,
                          currentChapterIndex: readerState.currentPosition.chapterIndex,
                          onJumpToPosition: _ctrl.jumpToPosition,
                          loadedChapters: readerState.loadedChapters,
                          isDynamicallyLoading: readerState.isDynamicallyLoading,
                        );
                      }
                    : null,
                onBookmark: () => _ctrl.addBookmark(),
                onMore: () => _showQuickSettings(context),
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
                chapterTitle: readerState.chapterTitle(readerState.currentPosition.chapterIndex),
                onJumpToProgress: _ctrl.jumpToProgress,
                onModeChanged: (mode) {
                  ref.read(readerSettingsProvider.notifier).updateMode(mode);
                },
                checkpoints: readerState.checkpoints,
                onCheckpointForward: _ctrl.hasCheckpointAhead
                    ? () => _ctrl.navigateToNearestCheckpoint(forward: true)
                    : null,
                onCheckpointBack: _ctrl.hasCheckpointBehind
                    ? () => _ctrl.navigateToNearestCheckpoint(forward: false)
                    : null,
              ),
            ),
          ),
        ),
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
                  currentChapterIndex: _ctrl.state.currentPosition.chapterIndex,
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
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: GestureDetector(
          onVerticalDragStart: _gestureCoordinator.canInteract && settings.verticalSwipeBrightness
              ? _handleVerticalDragStart
              : null,
          onVerticalDragUpdate: _gestureCoordinator.canInteract && settings.verticalSwipeBrightness
              ? _handleVerticalDragUpdate
              : null,
          onVerticalDragEnd: _gestureCoordinator.canInteract
              ? _handleVerticalDragEnd
              : null,
          onDoubleTap:
              _gestureCoordinator.canInteract &&
                  settings.doubleTapAction != DoubleTapAction.disabled
              ? _ctrl.handleDoubleTap
              : null,
          onHorizontalDragStart:
              _gestureCoordinator.canInteract && settings.horizontalGesture != HorizontalGesture.off
              ? _handleHorizontalDragStart
              : null,
          onHorizontalDragUpdate:
              _gestureCoordinator.canInteract && settings.horizontalGesture != HorizontalGesture.off
              ? _handleHorizontalDragUpdate
              : null,
          onHorizontalDragEnd:
              _gestureCoordinator.canInteract && settings.horizontalGesture != HorizontalGesture.off
              ? _handleHorizontalDragEnd
              : null,
          onLongPress:
              _gestureCoordinator.canInteract &&
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
              onTap: _gestureCoordinator.canInteract
                  ? (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width)
                  : (_) {},
              initialProgress: readerState.scrollProgress,
              initialPage: readerState.currentPosition.chapterIndex,
              highlightQuery: readerState.highlightedQuery,
              chapterHighlights: _buildChapterHighlights(),
              customColors: _resolveCustomColors(settings),
              onLinkTap: (href) => _handleLinkTap(href, readerState),
              onPageChanged: (chapterIndex) => _ctrl.handlePageChanged(chapterIndex),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderLayout(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final double horizontalPadding;
    if (screenWidth >= 840) {
      // Desktop: readerWidth with clamping
      final maxContentWidth = (screenWidth - 32.0).clamp(600.0, screenWidth);
      final effectiveWidth = settings.readerWidth.clamp(600.0, maxContentWidth);
      horizontalPadding = ((screenWidth - effectiveWidth) / 2).clamp(0.0, double.infinity);
    } else if (screenWidth >= 600) {
      // Tablet
      final maxContentWidth = screenWidth > 640 ? 720.0 : screenWidth - 32.0;
      final effectiveWidth = settings.readerWidth.clamp(600.0, maxContentWidth);
      horizontalPadding = ((screenWidth - effectiveWidth) / 2).clamp(16.0, 48.0);
    } else {
      // Phone
      final maxContentWidth = isLandscape ? 720.0 : double.infinity;
      horizontalPadding = isLandscape
          ? ((screenWidth - maxContentWidth) / 2).clamp(16.0, 48.0)
          : 0.0;
    }

    return Scaffold(
      backgroundColor: _getThemeData(settings).scaffoldBackgroundColor,
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

  ThemeData _getThemeData(ReaderSettings settings) {
    final base = Theme.of(context);
    final custom = _resolveCustomColors(settings);
    final colors = custom ?? ReaderColors.forTheme(settings.theme);
    return base.copyWith(
      scaffoldBackgroundColor: colors.scaffold,
      textTheme: base.textTheme.apply(bodyColor: colors.text),
    );
  }

  Widget _buildReadingInfoBar(
    BuildContext context,
    ReaderState readerState,
    ReaderSettings settings, {
    required _ReadingInfoPosition position,
  }) {
    final infoConfig = ref.watch(readingInfoProvider);
    final colors = _resolveCustomColors(settings) ?? ReaderColors.forTheme(settings.theme);
    final List<InfoSlotMode> slots = position == _ReadingInfoPosition.header
        ? [infoConfig.headerLeft, infoConfig.headerCenter, infoConfig.headerRight]
        : [infoConfig.footerLeft, infoConfig.footerCenter, infoConfig.footerRight];

    if (slots.every((s) => s == InfoSlotMode.none)) return const SizedBox.shrink();

    Widget buildSlot(InfoSlotMode mode) {
      if (mode == InfoSlotMode.none) return const SizedBox.shrink();
      final text = switch (mode) {
        InfoSlotMode.chapterTitle => readerState.chapterTitle(
          readerState.currentPosition.chapterIndex,
        ),
        InfoSlotMode.chapterProgress => '${(readerState.scrollProgress * 100).round()}%',
        InfoSlotMode.bookProgress =>
          '${readerState.currentPosition.chapterIndex + 1}/${readerState.chapterCount}',
        InfoSlotMode.time => _formatTime(),
        InfoSlotMode.battery => _formatBattery(),
        InfoSlotMode.batteryAndTime => '${_formatBattery()} ${_formatTime()}',
        InfoSlotMode.remainingChapter => _formatRemaining(
          readerState.scrollProgress,
          readerState.chapterCount - readerState.currentPosition.chapterIndex,
        ),
        InfoSlotMode.remainingBook => _formatRemaining(
          readerState.currentPosition.chapterIndex / readerState.chapterCount.clamp(1, 9999),
          readerState.chapterCount - readerState.currentPosition.chapterIndex,
        ),
        InfoSlotMode.none => '',
      };
      return Text(
        text,
        style: TextStyle(
          fontSize: infoConfig.fontSize,
          color: colors.text.withValues(alpha: 0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final bar = Container(
      padding: EdgeInsets.symmetric(horizontal: infoConfig.margin, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: buildSlot(slots[0])),
          Expanded(child: Center(child: buildSlot(slots[1]))),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: buildSlot(slots[2])),
          ),
        ],
      ),
    );

    if (position == _ReadingInfoPosition.header) {
      return Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: bar));
    }
    return Positioned(bottom: 0, left: 0, right: 0, child: SafeArea(top: false, child: bar));
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchBatteryLevel() async {
    try {
      final level = await Battery().batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } on Object catch (_) {}
  }

  String _formatBattery() {
    if (_batteryLevel < 0) return '';
    return '$_batteryLevel%';
  }

  String _formatRemaining(double progress, int chaptersLeft) {
    final remaining = (1.0 - progress).clamp(0.0, 1.0);
    final percent = (remaining * 100).round();
    if (chaptersLeft <= 1) return '$percent%';
    return '$percent% · $chaptersLeft гл.';
  }

  void _cycleColorPreset(int direction) {
    final presetsAsync = ref.read(colorPresetListProvider);
    final presets = presetsAsync.value;
    if (presets == null || presets.isEmpty) return;
    final currentSettings = ref.read(readerSettingsProvider);
    final currentId = currentSettings.activeColorPresetId;
    final currentIndex = presets.indexWhere((p) => p.id == currentId);
    final nextIndex = (currentIndex + direction).clamp(0, presets.length - 1);
    ref.read(readerSettingsProvider.notifier).updateActiveColorPresetId(presets[nextIndex].id);
  }

  void _showQuickSettings(BuildContext context) {
    _ctrl.saveCheckpoint();
    _ctrl.onBottomSheetOpen();
    _gestureCoordinator.onBottomSheetOpened();
    unawaited(
      showAdaptivePanel<void>(
        context: context,
        child: ReaderQuickSettingsSheet(bookId: widget.bookId),
      ).then((_) {
        _ctrl.onBottomSheetClose();
        _gestureCoordinator.onBottomSheetClosed();
      }),
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
                  unawaited(SmartDialog.showToast('Файл удалён'));
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
    if (!readerState.uiVisible) return false;
    return readerState.scrollProgress > 0;
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

  Map<int, List<TextHighlight>> _buildChapterHighlights() {
    final highlights = ref.watch(bookHighlightsProvider(widget.bookId)).value;
    final result = <int, List<TextHighlight>>{};
    if (highlights != null) {
      for (final h in highlights) {
        result.putIfAbsent(h.chapterIndex, () => []).add(h);
      }
    }
    return result;
  }

  ReaderColors? _resolveCustomColors(ReaderSettings settings) {
    final presetsAsync = ref.watch(colorPresetListProvider);
    final presets = presetsAsync.value;
    if (presets == null) return null;
    try {
      final preset = presets.firstWhere((p) => p.id == settings.activeColorPresetId);
      return ReaderColors.fromPreset(preset.backgroundColor, preset.fontColor);
    } on Object catch (_) {
      return null;
    }
  }
}

class _ScrollbarIndicator extends StatelessWidget {
  const _ScrollbarIndicator({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackH = constraints.maxHeight;
        final thumbH = (trackH * 0.15).clamp(20.0, trackH);
        final thumbTop = (trackH - thumbH) * progress.clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned(
              top: thumbTop,
              right: 0,
              child: Container(
                width: 3,
                height: thumbH,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
