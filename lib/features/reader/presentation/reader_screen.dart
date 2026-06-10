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
import 'reader_side_panel.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late final ReaderController _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _ctrl = ReaderController(widget.bookId, ref);
    unawaited(_ctrl.loadBook());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _ctrl.dispose();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(readerState.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _ctrl.loadBook(),
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
            ReaderContentBody(
              book: readerState.book!,
              settings: settings,
              scrollController: _ctrl.scrollController,
              onTap: (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width),
            ),
          if (readerState.uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: readerState.book?.title ?? '',
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
                currentChapterIndex: readerState.currentChapterIndex,
                totalChapters: readerState.book?.chapters.length ?? 0,
                scrollProgress: readerState.scrollProgress,
                estimatedMinutesLeft: readerState.estimatedMinutesLeft,
              ),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderProgressBar(
              scrollProgress: readerState.scrollProgress,
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
    const maxWidth = 720.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = ((screenWidth - maxWidth) / 2).clamp(32.0, 48.0);

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: readerState.book != null
                ? ReaderContentBody(
                    book: readerState.book!,
                    settings: settings,
                    scrollController: _ctrl.scrollController,
                    onTap: (details) => _ctrl.handleTap(details, MediaQuery.sizeOf(context).width),
                  )
                : const SizedBox.shrink(),
          ),
          if (readerState.uiVisible) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                settings: settings,
                bookTitle: readerState.book?.title ?? '',
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
                currentChapterIndex: readerState.currentChapterIndex,
                totalChapters: readerState.book?.chapters.length ?? 0,
                scrollProgress: readerState.scrollProgress,
                estimatedMinutesLeft: readerState.estimatedMinutesLeft,
              ),
            ),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderProgressBar(
              scrollProgress: readerState.scrollProgress,
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
    const maxWidth = 820.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
    const sidePanelWidth = 250.0;

    return Scaffold(
      backgroundColor: _getThemeData(settings.theme).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (readerState.book != null)
            ReaderSidePanel(
              book: readerState.book!,
              currentChapterIndex: readerState.currentChapterIndex,
              scrollController: _ctrl.scrollController,
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
                    horizontal: horizontalPadding.clamp(0.0, double.infinity),
                  ),
                  child: readerState.book != null
                      ? SelectionAreaWrapper(
                          child: ReaderContentBody(
                            book: readerState.book!,
                            settings: settings,
                            scrollController: _ctrl.scrollController,
                            onTap: (details) => _ctrl.handleTap(
                              details,
                              MediaQuery.sizeOf(context).width,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (readerState.uiVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ReaderTopBar(
                      settings: settings,
                      bookTitle: readerState.book?.title ?? '',
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
                      currentChapterIndex: readerState.currentChapterIndex,
                      totalChapters: readerState.book?.chapters.length ?? 0,
                      scrollProgress: readerState.scrollProgress,
                      estimatedMinutesLeft: readerState.estimatedMinutesLeft,
                    ),
                  ),
                ],
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReaderProgressBar(
                    scrollProgress: readerState.scrollProgress,
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
    if (settings.autoThemeMode == AutoThemeMode.off) return settings.theme;
    return AutoThemeService().resolveTheme(
      settings.autoThemeMode,
      settings.theme,
    );
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
}
