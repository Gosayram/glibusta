import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_duration.dart';
import '../../../core/utils/debouncer.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';
import 'reader_providers.dart';

@immutable
class ReaderState {
  final NormalizedBook? book;
  final bool isLoading;
  final String? errorMessage;
  final int currentChapterIndex;
  final bool uiVisible;
  final bool isBottomSheetOpen;
  final double scrollProgress;
  final int estimatedMinutesLeft;

  const ReaderState({
    this.book,
    this.isLoading = true,
    this.errorMessage,
    this.currentChapterIndex = 0,
    this.uiVisible = true,
    this.isBottomSheetOpen = false,
    this.scrollProgress = 0.0,
    this.estimatedMinutesLeft = 0,
  });

  ReaderState copyWith({
    NormalizedBook? book,
    bool? isLoading,
    String? errorMessage,
    int? currentChapterIndex,
    bool? uiVisible,
    bool? isBottomSheetOpen,
    double? scrollProgress,
    int? estimatedMinutesLeft,
  }) {
    return ReaderState(
      book: book ?? this.book,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      uiVisible: uiVisible ?? this.uiVisible,
      isBottomSheetOpen: isBottomSheetOpen ?? this.isBottomSheetOpen,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      estimatedMinutesLeft: estimatedMinutesLeft ?? this.estimatedMinutesLeft,
    );
  }
}

class ReaderController {
  ReaderController(this._bookId, this._ref);

  final String _bookId;
  final WidgetRef _ref;
  final _autoThemeService = AutoThemeService();
  final _progressDebouncer = Debouncer(delay: AppDuration.readerProgressSave);
  Timer? _hideTimer;
  Timer? _autoThemeTimer;
  ScrollController? _scrollController;
  ReaderState _state = const ReaderState();
  bool _disposed = false;

  ReaderState get state => _state;

  void dispose() {
    _disposed = true;
    _progressDebouncer.dispose();
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    saveProgress();
    unawaited(WakelockPlus.disable());
  }

  void _applyWakeLock() {
    final keepAwake = _ref.read(readerSettingsProvider).keepScreenAwake;
    if (keepAwake) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  void _updateState(ReaderState newState) {
    if (_disposed) return;
    _state = newState;
  }

  Future<void> loadBook() async {
    _updateState(_state.copyWith(isLoading: true));
    try {
      final service = _ref.read(bookOpenServiceProvider);
      final book = await service.openBookWithCache(_bookId);
      final savedChapter = await _loadSavedChapterIndex();
      final totalWords = book.chapters.fold<int>(0, (sum, ch) {
        final chapterWords = ch.blocks.fold<int>(
          0,
          (bSum, block) => bSum + block.text.split(RegExp(r'\s+')).length,
        );
        return sum + chapterWords;
      });
      const wordsPerMinute = 200;
      _updateState(
        _state.copyWith(
          book: book,
          isLoading: false,
          currentChapterIndex: savedChapter.clamp(0, book.chapters.length - 1),
          estimatedMinutesLeft: (totalWords / wordsPerMinute).ceil(),
        ),
      );
      _scrollController = ScrollController()..addListener(_onScroll);
      _autoThemeTimer = Timer.periodic(
        AppDuration.autoThemeCheck,
        (_) => _checkAutoTheme(),
      );
      _startHideTimer();
      _applyWakeLock();
    } on Object catch (e) {
      _updateState(_state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  ScrollController get scrollController {
    _scrollController ??= ScrollController()..addListener(_onScroll);
    return _scrollController!;
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress = _scrollController!.offset / maxScroll;
      _updateState(_state.copyWith(scrollProgress: progress.clamp(0.0, 1.0)));
      _updateChapterFromScroll();
      _progressDebouncer.call(saveProgress);
    }
  }

  void _updateChapterFromScroll() {
    if (_state.book == null || _state.book!.chapters.isEmpty) return;
    final chapterCount = _state.book!.chapters.length;
    final estimatedChapter = (_state.scrollProgress * chapterCount).floor().clamp(
      0,
      chapterCount - 1,
    );
    if (estimatedChapter != _state.currentChapterIndex) {
      _updateState(_state.copyWith(currentChapterIndex: estimatedChapter));
      _ref
          .read(readingProgressProvider.notifier)
          .updateProgress(
            ReadingProgress(
              bookId: _bookId,
              currentPosition: estimatedChapter,
              lastRead: DateTime.now(),
            ),
          );
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    final delay = _ref.read(readerSettingsProvider).autoHideDelay;
    if (delay <= 0) return;
    _hideTimer = Timer(Duration(seconds: delay), () {
      if (!_state.isBottomSheetOpen) {
        _updateState(_state.copyWith(uiVisible: false));
      }
    });
  }

  void toggleUi() {
    _updateState(_state.copyWith(uiVisible: !_state.uiVisible));
    if (_state.uiVisible) _startHideTimer();
  }

  void _checkAutoTheme() {
    final settings = _ref.read(readerSettingsProvider);
    if (settings.autoThemeMode == AutoThemeMode.off) return;
    final resolved = _autoThemeService.resolveTheme(
      settings.autoThemeMode,
      settings.theme,
    );
    final autoWarmth = _autoThemeService.resolveWarmth(
      settings.autoThemeMode,
      resolved,
    );
    final notifier = _ref.read(readerSettingsProvider.notifier);
    if (resolved != settings.theme) {
      notifier.updateTheme(resolved);
    }
    if ((autoWarmth - settings.warmth).abs() > 0.01) {
      notifier.updateWarmth(autoWarmth);
    }
  }

  Future<int> _loadSavedChapterIndex() async {
    try {
      final db = _ref.read(databaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.bookId.equals(_bookId))).getSingleOrNull();
      return row?.currentPosition ?? 0;
    } on Object catch (_) {
      return 0;
    }
  }

  void saveProgress() {
    if (_state.book == null) return;
    final database = _ref.read(databaseProvider);
    unawaited(
      database.upsertReadingProgress(
        ReadingProgressCompanion.insert(
          bookId: _bookId,
          currentPosition: Value(_state.currentChapterIndex),
          totalPages: Value(_state.book!.chapters.length),
        ),
      ),
    );
  }

  void scrollToNext() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    final currentScroll = _scrollController!.offset;
    final viewportHeight = _scrollController!.position.viewportDimension;
    final nextOffset = currentScroll + viewportHeight * 0.8;
    unawaited(
      _scrollController!.animateTo(
        nextOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  void scrollToPrevious() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final currentScroll = _scrollController!.offset;
    final viewportHeight = _scrollController!.position.viewportDimension;
    final prevOffset = currentScroll - viewportHeight * 0.8;
    unawaited(
      _scrollController!.animateTo(
        prevOffset.clamp(0.0, double.infinity),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  void handleTap(TapUpDetails details, double width) {
    final settings = _ref.read(readerSettingsProvider);
    final x = details.localPosition.dx;
    final threshold1 = switch (settings.tapZoneLayout) {
      TapZoneLayout.third => width / 3,
      TapZoneLayout.quarter => width / 4,
      TapZoneLayout.edge => width * 0.15,
    };
    final threshold2 = width - threshold1;
    if (x < threshold1) {
      scrollToPrevious();
    } else if (x > threshold2) {
      scrollToNext();
    } else {
      toggleUi();
    }
  }

  void handleDoubleTap() {
    final settings = _ref.read(readerSettingsProvider);
    switch (settings.doubleTapAction) {
      case DoubleTapAction.toggleUI:
        toggleUi();
        break;
      case DoubleTapAction.addBookmark:
        // TODO: Add bookmark
        break;
      case DoubleTapAction.toggleFullscreen:
        // Toggle fullscreen mode would require app-level handling
        break;
      case DoubleTapAction.disabled:
        break;
    }
  }

  void handleLongPress() {
    final settings = _ref.read(readerSettingsProvider);
    switch (settings.longPressAction) {
      case LongPressAction.selectText:
        break;
      case LongPressAction.addBookmark:
        _addBookmarkAtCurrentChapter();
        break;
      case LongPressAction.openMenu:
        toggleUi();
        break;
      case LongPressAction.disabled:
        break;
    }
  }

  void _addBookmarkAtCurrentChapter() {
    if (_state.book == null) return;
    final database = _ref.read(databaseProvider);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(
      database
          .into(database.bookmarks)
          .insertOnConflictUpdate(
            Bookmark(
              id: id,
              bookId: _bookId,
              chapterIndex: _state.currentChapterIndex,
              paragraphIndex: 0,
              localOffset: _state.scrollProgress * 100.0,
              createdAt: DateTime.now(),
            ),
          ),
    );
  }

  void jumpToProgress(double progress) {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    unawaited(
      _scrollController!.animateTo(
        (progress * maxScroll).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  void onBottomSheetOpen() {
    _updateState(_state.copyWith(isBottomSheetOpen: true));
    _hideTimer?.cancel();
  }

  void onBottomSheetClose() {
    _updateState(_state.copyWith(isBottomSheetOpen: false));
    _startHideTimer();
  }
}
