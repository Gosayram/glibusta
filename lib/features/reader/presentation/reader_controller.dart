import 'dart:async';
import 'dart:developer' as developer;
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

const int _chapterWindowSize = 2;

@immutable
class ReaderState {
  final NormalizedBookMetadata? metadata;
  final Map<int, ReaderChapter> loadedChapters;
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
    this.metadata,
    this.loadedChapters = const {},
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

  int get chapterCount => metadata?.chapterCount ?? 0;

  ReaderChapter? chapterAt(int index) => loadedChapters[index];

  String chapterTitle(int index) {
    final titles = metadata?.chapterTitles;
    if (titles != null && index >= 0 && index < titles.length) {
      return titles[index];
    }
    return '';
  }

  ReaderState copyWith({
    NormalizedBookMetadata? metadata,
    Map<int, ReaderChapter>? loadedChapters,
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
      metadata: metadata ?? this.metadata,
      loadedChapters: loadedChapters ?? this.loadedChapters,
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

  Future<void> _ensureChaptersLoaded(int centerIndex, {int windowSize = _chapterWindowSize}) async {
    final service = _ref.read(bookOpenServiceProvider);
    final bookId = _bookId;
    final total = _state.chapterCount;
    if (total == 0) return;

    final minIdx = (centerIndex - windowSize).clamp(0, total - 1);
    final maxIdx = (centerIndex + windowSize).clamp(0, total - 1);

    final toLoad = <int>[];
    for (var i = minIdx; i <= maxIdx; i++) {
      if (!_state.loadedChapters.containsKey(i)) {
        toLoad.add(i);
      }
    }

    if (toLoad.isEmpty) return;

    final updates = Map<int, ReaderChapter>.from(_state.loadedChapters);
    for (final idx in toLoad) {
      final chapter = await service.loadChapter(bookId, idx);
      if (chapter != null) {
        updates[idx] = chapter;
      }
    }
    _updateState(_state.copyWith(loadedChapters: updates));
  }

  void _evictDistantChapters(int centerIndex, {int windowSize = _chapterWindowSize + 1}) {
    final total = _state.chapterCount;
    if (total == 0) return;

    final minKeep = (centerIndex - windowSize).clamp(0, total - 1);
    final maxKeep = (centerIndex + windowSize).clamp(0, total - 1);

    final updated = Map<int, ReaderChapter>.from(_state.loadedChapters);
    final keysToRemove = <int>[];
    for (final key in updated.keys) {
      if (key < minKeep || key > maxKeep) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        updated.remove(key);
      }
      _updateState(_state.copyWith(loadedChapters: updated));
    }
  }

  Future<void> loadBook() async {
    _updateState(_state.copyWith(isLoading: true));
    try {
      final service = _ref.read(bookOpenServiceProvider);

      // Load metadata
      final metadata = await service.getCachedMetadata(_bookId);
      NormalizedBookMetadata meta;
      if (metadata != null) {
        meta = metadata;
      } else {
        // Full parse — need metadata
        final book = await service.openBookWithCache(_bookId);
        meta = book.toMetadata();
      }

      final savedPosition = await _loadSavedPosition(meta.chapterCount);

      // Estimate total words from chapter count (rough estimate until chapters are loaded)
      // We'll update this once chapters are loaded
      const wordsPerMinute = 200;

      _updateState(
        _state.copyWith(
          metadata: meta,
          isLoading: false,
          currentPosition: savedPosition.clamp(chapterCount: meta.chapterCount),
          clearHighlight: true,
        ),
      );
      _scrollController = ScrollController()..addListener(_onScroll);

      // Pre-load the initial chapter window
      final startChapter = savedPosition.chapterIndex;
      await _ensureChaptersLoaded(startChapter);

      // Compute accurate word count from loaded chapters
      final totalWords = _computeTotalWords();
      _updateState(
        _state.copyWith(
          estimatedMinutesLeft: totalWords > 0 ? (totalWords / wordsPerMinute).ceil() : 0,
        ),
      );

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
      } on Object catch (e, st) {
        developer.log(
          'Download lookup failed during error recovery',
          name: 'ReaderController',
          error: e,
          stackTrace: st,
        );
      }
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

  int _computeTotalWords() {
    var total = 0;
    for (final chapter in _state.loadedChapters.values) {
      for (final block in chapter.blocks) {
        total += block.text.split(RegExp(r'\s+')).length;
      }
    }
    return total;
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
    final total = _state.chapterCount;
    if (total == 0) return;
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
          ReadingProgress.fromPosition(position, totalPages: total),
        );
  }

  ReaderPosition _positionFromProgress(double progress) {
    final total = _state.chapterCount;
    if (total == 0) {
      return ReaderPosition(
        bookId: _bookId,
        chapterIndex: 0,
        paragraphIndex: 0,
        updatedAt: DateTime.now(),
      );
    }
    final lastChapter = total - 1;
    final chapterIndex = (progress * lastChapter).round().clamp(0, lastChapter);
    final chapter = _state.chapterAt(chapterIndex);
    final lastParagraph = (chapter?.blocks.isEmpty ?? true) ? 0 : chapter!.blocks.length - 1;
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
    } on Object catch (e, st) {
      developer.log(
        'Failed to load reading position',
        name: 'ReaderController',
        error: e,
        stackTrace: st,
      );
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
    final total = _state.chapterCount;
    if (total == 0) return;
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
          totalPages: Value(total),
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
        _state.chapterCount - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(chapterIndex: nextChapter),
        ),
      );
      unawaited(_ensureChaptersLoaded(nextChapter));
      _evictDistantChapters(nextChapter);
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
        _state.chapterCount - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(chapterIndex: previousChapter),
        ),
      );
      unawaited(_ensureChaptersLoaded(previousChapter));
      _evictDistantChapters(previousChapter);
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
    final total = _state.chapterCount;
    if (total == 0) return;
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
    final total = _state.chapterCount;
    if (total == 0) return;
    final clamped = position.clamp(chapterCount: total);
    final settings = _ref.read(readerSettingsProvider);
    if (settings.mode == ReaderMode.paginated || settings.mode == ReaderMode.twoPage) {
      _updateState(_state.copyWith(currentPosition: clamped));
      unawaited(_ensureChaptersLoaded(clamped.chapterIndex));
      _evictDistantChapters(clamped.chapterIndex);
      return;
    }
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final progress = clamped.progressPercent > 0
        ? clamped.progressPercent
        : (total > 1 ? clamped.chapterIndex / (total - 1) : 0.0);
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
    final meta = _state.metadata;
    if (meta == null) return null;
    // Build a NormalizedBook from metadata + loaded chapters for search
    final chapters = <ReaderChapter>[];
    for (var i = 0; i < meta.chapterCount; i++) {
      chapters.add(
        _state.chapterAt(i) ??
            ReaderChapter(index: i, title: meta.chapterTitles[i], blocks: const []),
      );
    }
    final book = NormalizedBook(
      id: meta.id,
      title: meta.title,
      authors: meta.authors,
      description: meta.description,
      coverUrl: meta.coverUrl,
      chapters: chapters,
      metadata: meta.metadata,
    );
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
    } on Object catch (e, st) {
      developer.log(
        'Error during file deletion cleanup',
        name: 'ReaderController',
        error: e,
        stackTrace: st,
      );
    }
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
    buffer.writeln('Chapters: ${_state.chapterCount}');
    buffer.writeln('Loaded chapters: ${_state.loadedChapters.length}');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
    return buffer.toString();
  }

  void copyDiagnostics() {
    final diagnostics = buildDiagnostics();
    unawaited(Clipboard.setData(ClipboardData(text: diagnostics)));
  }
}
