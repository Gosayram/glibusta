import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart' show DownloadStatusDb;
import '../../../core/theme/app_duration.dart';
import '../../../core/utils/debouncer.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/book_search_service.dart';
import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';
import 'reader_providers.dart';

@immutable
class ReaderState {
  final NormalizedBook? book;
  final bool isLoading;
  final String? errorMessage;
  final String? errorFilePath;
  final String? errorFormat;
  final int? errorFileSize;
  final ReaderPosition currentPosition;
  final bool uiVisible;
  final bool isBottomSheetOpen;
  final double scrollProgress;
  final int estimatedMinutesLeft;
  final bool isSearchOpen;
  final String? highlightedQuery;

  // ignore: prefer_const_constructors_in_immutables
  ReaderState({
    this.book,
    this.isLoading = true,
    this.errorMessage,
    this.errorFilePath,
    this.errorFormat,
    this.errorFileSize,
    ReaderPosition? currentPosition,
    this.uiVisible = true,
    this.isBottomSheetOpen = false,
    this.scrollProgress = 0.0,
    this.estimatedMinutesLeft = 0,
    this.isSearchOpen = false,
    this.highlightedQuery,
  }) : currentPosition = currentPosition ?? ReaderPosition.initial;

  ReaderState copyWith({
    NormalizedBook? book,
    bool? isLoading,
    String? errorMessage,
    String? errorFilePath,
    String? errorFormat,
    int? errorFileSize,
    ReaderPosition? currentPosition,
    bool? uiVisible,
    bool? isBottomSheetOpen,
    double? scrollProgress,
    int? estimatedMinutesLeft,
    bool? isSearchOpen,
    String? highlightedQuery,
    bool clearHighlight = false,
  }) {
    return ReaderState(
      book: book ?? this.book,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      errorFilePath: errorFilePath ?? this.errorFilePath,
      errorFormat: errorFormat ?? this.errorFormat,
      errorFileSize: errorFileSize ?? this.errorFileSize,
      currentPosition: currentPosition ?? this.currentPosition,
      uiVisible: uiVisible ?? this.uiVisible,
      isBottomSheetOpen: isBottomSheetOpen ?? this.isBottomSheetOpen,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      estimatedMinutesLeft: estimatedMinutesLeft ?? this.estimatedMinutesLeft,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      highlightedQuery: clearHighlight ? null : (highlightedQuery ?? this.highlightedQuery),
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
  ReaderState _state = ReaderState();
  final _stateController = StreamController<ReaderState>.broadcast();
  bool _disposed = false;
  bool _fullscreenEnabled = false;

  ReaderState get state => _state;
  Stream<ReaderState> get stateStream => _stateController.stream;

  void dispose() {
    _disposed = true;
    _progressDebouncer.dispose();
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    disableFullscreen();
    saveProgress();
    unawaited(WakelockPlus.disable());
    unawaited(_stateController.close());
  }

  void _applyWakeLock() {
    final keepAwake = _ref.read(readerSettingsProvider).keepScreenAwake;
    if (keepAwake) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  void enableFullscreen() {
    if (_fullscreenEnabled) return;
    _fullscreenEnabled = true;
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  void disableFullscreen() {
    if (!_fullscreenEnabled) return;
    _fullscreenEnabled = false;
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  void _updateState(ReaderState newState) {
    if (_disposed) return;
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  Future<void> loadBook() async {
    _updateState(_state.copyWith(isLoading: true));
    try {
      final service = _ref.read(bookOpenServiceProvider);
      final book = await service.openBookWithCache(_bookId);
      final savedPosition = await _loadSavedPosition(book.chapters.length);
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
          currentPosition: savedPosition.clamp(chapterCount: book.chapters.length),
          estimatedMinutesLeft: (totalWords / wordsPerMinute).ceil(),
          clearHighlight: true,
        ),
      );
      _scrollController = ScrollController()..addListener(_onScroll);
      final settings = _ref.read(readerSettingsProvider);
      if (settings.restoreLastPosition && savedPosition.progressPercent > 0) {
        _restoreSavedPosition(savedPosition);
      }
      _autoThemeTimer = Timer.periodic(
        AppDuration.autoThemeCheck,
        (_) => _checkAutoTheme(),
      );
      _startHideTimer();
      _applyWakeLock();
    } on Object catch (e) {
      String? filePath;
      String? format;
      int? fileSize;
      try {
        final db = _ref.read(databaseProvider);
        final rows = await (db.select(db.downloads)..where((d) => d.bookId.equals(_bookId))).get();
        for (final row in rows) {
          if (row.status == DownloadStatusDb.completed) {
            filePath = row.targetPath;
            format = row.format;
            if (filePath != null && filePath.isNotEmpty) {
              final file = File(filePath);
              if (await file.exists()) {
                fileSize = await file.length();
              }
            }
            break;
          }
        }
      } on Object catch (_) {}
      _updateState(
        _state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          errorFilePath: filePath,
          errorFormat: format,
          errorFileSize: fileSize,
        ),
      );
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
      final boundedProgress = progress.clamp(0.0, 1.0);
      _updateState(_state.copyWith(scrollProgress: boundedProgress));
      _updatePositionFromScroll(boundedProgress);
      _progressDebouncer.call(saveProgress);
    }
  }

  void _updatePositionFromScroll(double progress) {
    if (_state.book == null || _state.book!.chapters.isEmpty) return;
    final position = _positionFromProgress(progress);
    if (position.chapterIndex == _state.currentPosition.chapterIndex &&
        position.paragraphIndex == _state.currentPosition.paragraphIndex &&
        (position.localOffset - _state.currentPosition.localOffset).abs() < 0.5) {
      return;
    }
    _updateState(_state.copyWith(currentPosition: position));
    _ref
        .read(readingProgressProvider.notifier)
        .updateProgress(
          ReadingProgress.fromPosition(position, totalPages: _state.book!.chapters.length),
        );
  }

  ReaderPosition _positionFromProgress(double progress) {
    final book = _state.book!;
    if (book.chapters.isEmpty) {
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: DateTime.now(),
      );
    }
    final lastChapter = book.chapters.length - 1;
    final chapterIndex = (progress * lastChapter).round().clamp(0, lastChapter);
    final chapter = book.chapters[chapterIndex];
    final lastParagraph = chapter.blocks.isEmpty ? 0 : chapter.blocks.length - 1;
    final paragraphIndex = (progress * lastParagraph).round().clamp(0, lastParagraph);
    return ReaderPosition(
      bookId: _bookId,
      chapterIndex: chapterIndex,
      paragraphIndex: paragraphIndex,
      localOffset: progress * 100.0,
      progressPercent: progress,
      updatedAt: DateTime.now(),
    );
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

  Future<ReaderPosition> _loadSavedPosition(int chapterCount) async {
    try {
      final db = _ref.read(databaseProvider);
      final row = await (db.select(
        db.readingProgress,
      )..where((t) => t.bookId.equals(_bookId))).getSingleOrNull();
      if (row == null) {
        return ReaderPosition(
          bookId: _bookId,
          chapterIndex: 0,
          paragraphIndex: 0,
          updatedAt: DateTime.now(),
        );
      }
      final progressPercent = row.progressPercent <= 0 && row.totalPages > 0
          ? row.chapterIndex / row.totalPages
          : row.progressPercent;
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: row.chapterIndex,
        paragraphIndex: row.paragraphIndex,
        localOffset: row.localOffset,
        progressPercent: progressPercent.clamp(0.0, 1.0),
        updatedAt: row.updatedAt,
      ).clamp(chapterCount: chapterCount);
    } on Object catch (_) {
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: DateTime.now(),
      );
    }
  }

  void _restoreSavedPosition(ReaderPosition position) {
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      _updateState(_state.copyWith(currentPosition: position));
      return;
    }
    if (_scrollController == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _scrollController == null || !_scrollController!.hasClients) return;
      final maxScroll = _scrollController!.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      unawaited(
        _scrollController!.animateTo(
          (position.progressPercent * maxScroll).clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  void saveProgress() {
    if (_state.book == null) return;
    final database = _ref.read(databaseProvider);
    final position = _state.currentPosition.copyWith(
      bookId: _bookId,
      updatedAt: DateTime.now(),
    );
    unawaited(
      database.upsertReadingProgress(
        ReadingProgressCompanion.insert(
          bookId: _bookId,
          currentPosition: Value(position.chapterIndex),
          chapterIndex: Value(position.chapterIndex),
          paragraphIndex: Value(position.paragraphIndex),
          localOffset: Value(position.localOffset),
          progressPercent: Value(position.progressPercent),
          totalPages: Value(_state.book!.chapters.length),
          lastRead: Value(position.updatedAt),
          updatedAt: Value(position.updatedAt),
        ),
      ),
    );
  }

  void scrollToNext() {
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      final step = settings.mode == ReaderMode.twoPage ? 2 : 1;
      final nextChapter = (_state.currentPosition.chapterIndex + step).clamp(
        0,
        (_state.book?.chapters.length ?? 1) - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(chapterIndex: nextChapter),
        ),
      );
      return;
    }
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
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      final step = settings.mode == ReaderMode.twoPage ? 2 : 1;
      final previousChapter = (_state.currentPosition.chapterIndex - step).clamp(
        0,
        (_state.book?.chapters.length ?? 1) - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(chapterIndex: previousChapter),
        ),
      );
      return;
    }
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
        addBookmark();
        break;
      case DoubleTapAction.toggleFullscreen:
        final notifier = _ref.read(readerSettingsProvider.notifier);
        final currentMode = _ref.read(readerSettingsProvider).mode;
        notifier.updateMode(
          currentMode == ReaderMode.fullscreen ? ReaderMode.continuous : ReaderMode.fullscreen,
        );
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
        addBookmark();
        break;
      case LongPressAction.openMenu:
        toggleUi();
        break;
      case LongPressAction.disabled:
        break;
    }
  }

  void addBookmark() {
    if (_state.book == null) return;
    final position = _state.currentPosition.copyWith(bookId: _bookId, updatedAt: DateTime.now());
    final database = _ref.read(databaseProvider);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(
      database
          .into(database.bookmarks)
          .insertOnConflictUpdate(
            Bookmark(
              id: id,
              bookId: _bookId,
              chapterIndex: position.chapterIndex,
              paragraphIndex: position.paragraphIndex,
              localOffset: position.localOffset / 100.0,
              createdAt: position.updatedAt,
            ),
          ),
    );
  }

  void jumpToPosition(ReaderPosition position) {
    if (_state.book == null || _state.book!.chapters.isEmpty) return;
    final clamped = position.clamp(chapterCount: _state.book!.chapters.length);
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      _updateState(_state.copyWith(currentPosition: clamped));
      return;
    }
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final chapterCount = _state.book!.chapters.length;
    final progress = clamped.progressPercent > 0
        ? clamped.progressPercent
        : (chapterCount > 1 ? clamped.chapterIndex / (chapterCount - 1) : 0.0);
    final maxScroll = _scrollController!.position.maxScrollExtent;
    unawaited(
      _scrollController!.animateTo(
        (progress * maxScroll).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  void jumpToProgress(double progress) {
    final bounded = progress.clamp(0.0, 1.0);
    _updateState(
      _state.copyWith(currentPosition: _positionFromProgress(bounded), scrollProgress: bounded),
    );
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) return;
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    unawaited(
      _scrollController!.animateTo(
        (bounded * maxScroll).clamp(0.0, maxScroll),
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

  BookSearchService? createSearchService() {
    final book = _state.book;
    if (book == null) return null;
    return BookSearchService(book);
  }

  void toggleSearch() {
    final shouldOpen = !_state.isSearchOpen;
    _updateState(_state.copyWith(isSearchOpen: shouldOpen, clearHighlight: shouldOpen));
  }

  void closeSearch() {
    _updateState(_state.copyWith(isSearchOpen: false, clearHighlight: true));
  }

  void highlightSearchQuery(String query) {
    final trimmed = query.trim();
    _updateState(
      _state.copyWith(
        highlightedQuery: trimmed.isEmpty ? null : trimmed,
        clearHighlight: trimmed.isEmpty,
      ),
    );
  }

  void clearHighlight() {
    _updateState(_state.copyWith(clearHighlight: true));
  }

  Future<void> deleteBookFile() async {
    final filePath = _state.errorFilePath;
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      final db = _ref.read(databaseProvider);
      await (db.delete(db.downloads)..where((d) => d.bookId.equals(_bookId))).go();
      await (db.delete(db.readingProgress)..where((t) => t.bookId.equals(_bookId))).go();
    } on Object catch (_) {}
    _updateState(
      _state.copyWith(
        errorMessage: 'Файл удалён',
      ),
    );
  }

  String buildDiagnostics() {
    final buffer = StringBuffer();
    buffer.writeln('=== Diagnostics ===');
    buffer.writeln('Book ID: $_bookId');
    buffer.writeln('Error: ${_state.errorMessage ?? "none"}');
    buffer.writeln('File: ${_state.errorFilePath ?? "unknown"}');
    buffer.writeln('Format: ${_state.errorFormat ?? "unknown"}');
    buffer.writeln(
      'Size: ${_state.errorFileSize != null ? "${(_state.errorFileSize! / 1024).toStringAsFixed(1)} KB" : "unknown"}',
    );
    buffer.writeln('Chapters: ${_state.book?.chapters.length ?? 0}');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
    return buffer.toString();
  }

  void copyDiagnostics() {
    final diagnostics = buildDiagnostics();
    unawaited(Clipboard.setData(ClipboardData(text: diagnostics)));
  }
}
