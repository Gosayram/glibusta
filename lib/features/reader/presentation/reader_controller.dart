import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables.dart' show DownloadStatusDb;
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_duration.dart';
import '../../../core/utils/debouncer.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/book_search_service.dart';
import '../data/parsers/normalized_book.dart';
import '../domain/reader.dart';
import 'reader_content_helper.dart';
import 'reader_progress_helper.dart';
import 'reader_providers.dart';

enum ReaderErrorKind {
  bookMissing('Книга не найдена', Icons.search_off),
  unsupportedFormat('Формат не поддерживается', Icons.block),
  parserTimeout('Превышено время ожидания', Icons.hourglass_empty),
  cacheCorrupted('Повреждённый кеш', Icons.broken_image_outlined),
  invalidEncoding('Ошибка кодировки', Icons.text_fields),
  unknown('Ошибка открытия книги', Icons.error_outline);

  const ReaderErrorKind(this.defaultTitle, this.icon);
  final String defaultTitle;
  final IconData icon;
}

@immutable
class ReaderState {
  final NormalizedBookMetadata? metadata;
  final Map<int, ReaderChapter> loadedChapters;
  final ReaderLoadingStage? loadingStage;
  final String? errorMessage;
  final ReaderErrorKind? errorKind;
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
    this.loadingStage = ReaderLoadingStage.openingFile,
    this.errorMessage,
    this.errorKind,
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

  bool get isLoading => loadingStage != null;

  String? get loadingMessage => loadingStage?.message;

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
    ReaderLoadingStage? loadingStage,
    bool clearLoadingStage = false,
    String? errorMessage,
    ReaderErrorKind? errorKind,
    bool clearError = false,
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
    bool clearLoadingMessage = false,
  }) {
    return ReaderState(
      metadata: metadata ?? this.metadata,
      loadedChapters: loadedChapters ?? this.loadedChapters,
      loadingStage: clearLoadingStage ? null : (loadingStage ?? this.loadingStage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      errorFilePath: clearError ? null : (errorFilePath ?? this.errorFilePath),
      errorFormat: clearError ? null : (errorFormat ?? this.errorFormat),
      errorFileSize: clearError ? null : (errorFileSize ?? this.errorFileSize),
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
  bool _loaded = false;
  bool _fullscreenEnabled = false;
  int _loadGeneration = 0;

  late final ReaderContentHelper _content;
  late final ReaderProgressHelper _progress;

  ReaderState get state => _state;
  Stream<ReaderState> get stateStream => _stateController.stream;

  void dispose() {
    _disposed = true;
    _loadGeneration++;
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

  void _updateState(ReaderState newState) {
    if (_disposed) return;
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  // ── Load ──────────────────────────────────────────────

  Future<void> loadBook() async {
    final loadGeneration = ++_loadGeneration;
    _loaded = false;
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    _autoThemeTimer = null;
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _scrollController = null;
    _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.openingFile));

    final service = _ref.read(bookOpenServiceProvider);
    final db = _ref.read(databaseProvider);
    _content = ReaderContentHelper(service, _bookId);
    _progress = ReaderProgressHelper(db, _bookId);

    try {
      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.readingMetadata));
      final meta = await _content.loadMetadata();
      if (!_isActiveLoad(loadGeneration)) return;
      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.loadingChapters));
      final savedPosition = await _progress.loadSavedPosition(meta.chapterCount);
      if (!_isActiveLoad(loadGeneration)) return;

      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.loadingChapters));
      _updateState(
        _state.copyWith(
          metadata: meta,
          currentPosition: savedPosition.clamp(chapterCount: meta.chapterCount),
          clearHighlight: true,
        ),
      );
      _scrollController?.removeListener(_onScroll);
      _scrollController?.dispose();
      _scrollController = ScrollController()..addListener(_onScroll);

      await _ensureChaptersLoaded(savedPosition.chapterIndex);
      if (!_isActiveLoad(loadGeneration)) return;
      _loaded = true;
      _updateState(_state.copyWith(clearLoadingStage: true, clearError: true));

      const wordsPerMinute = 200;
      final totalWords = _content.computeTotalWords(_state.loadedChapters);
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
    } on TimeoutException {
      if (!_isActiveLoad(loadGeneration)) return;
      _updateState(
        _state.copyWith(
          clearLoadingStage: true,
          errorKind: ReaderErrorKind.parserTimeout,
          errorMessage:
              'Открытие книги заняло слишком много времени.\n'
              'Возможно, файл повреждён или слишком большой.\n'
              'Попробуйте повторить.',
        ),
      );
    } on Object catch (e) {
      if (!_isActiveLoad(loadGeneration)) return;
      await _handleLoadError(e, loadGeneration: loadGeneration);
    }
  }

  bool _isActiveLoad(int loadGeneration) {
    return !_disposed && loadGeneration == _loadGeneration;
  }

  static ReaderErrorKind _classifyError(Object error) => switch (error) {
    BookMissingFailure() => ReaderErrorKind.bookMissing,
    UnsupportedFormatFailure() => ReaderErrorKind.unsupportedFormat,
    ParserTimeoutFailure() => ReaderErrorKind.parserTimeout,
    CacheCorruptedFailure() => ReaderErrorKind.cacheCorrupted,
    InvalidEncodingFailure() => ReaderErrorKind.invalidEncoding,
    TimeoutException() => ReaderErrorKind.parserTimeout,
    BookOpenFailure() => ReaderErrorKind.unknown,
    _ => ReaderErrorKind.unknown,
  };

  Future<void> _handleLoadError(Object e, {required int loadGeneration}) async {
    final errorKind = _classifyError(e);
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
    } on Object catch (e) {
      AppLogger().warning(
        'Download lookup failed during error recovery: $e',
        name: 'Reader',
        error: e,
      );
    }
    if (!_isActiveLoad(loadGeneration)) return;
    _updateState(
      _state.copyWith(
        clearLoadingStage: true,
        errorKind: errorKind,
        errorMessage: e.toString(),
        errorFilePath: filePath,
        errorFormat: format,
        errorFileSize: fileSize,
      ),
    );
  }

  // ── Chapter windowing ─────────────────────────────────

  Future<void> _ensureChaptersLoaded(int centerIndex) async {
    final updated = await _content.ensureChaptersLoaded(
      centerIndex,
      _state.loadedChapters,
      chapterCount: _state.chapterCount,
    );
    if (!_disposed) {
      _updateState(_state.copyWith(loadedChapters: updated));
    }
  }

  void _evictDistantChapters(int centerIndex) {
    final updated = _content.evictDistantChapters(centerIndex, _state.loadedChapters);
    if (updated.length != _state.loadedChapters.length) {
      _updateState(_state.copyWith(loadedChapters: updated));
    }
  }

  // ── Scroll / progress ─────────────────────────────────

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
    if (!_loaded) return;
    _progress.saveProgress(_state.currentPosition, _state.chapterCount);
  }

  // ── Navigation ────────────────────────────────────────

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

  // ── Gestures ──────────────────────────────────────────

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

  // ── UI state ──────────────────────────────────────────

  void toggleUi() {
    _updateState(_state.copyWith(uiVisible: !_state.uiVisible));
    if (_state.uiVisible) _startHideTimer();
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

  void onBottomSheetOpen() {
    _updateState(_state.copyWith(isBottomSheetOpen: true));
    _hideTimer?.cancel();
  }

  void onBottomSheetClose() {
    _updateState(_state.copyWith(isBottomSheetOpen: false));
    _startHideTimer();
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

  // ── Theme / system ────────────────────────────────────

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

  // ── Actions ───────────────────────────────────────────

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

  BookSearchService? createSearchService() {
    final meta = _state.metadata;
    if (meta == null) return null;
    final book = _content.buildBookForSearch(meta, _state.loadedChapters);
    return BookSearchService(book);
  }

  Future<void> deleteBookFile() async {
    final filePath = _state.errorFilePath;
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      if (_loaded) {
        await _progress.deleteDownload();
        await _progress.deleteProgress();
      }
    } on Object catch (e) {
      AppLogger().warning('Error during file deletion: $e', name: 'Reader', error: e);
    }
    _updateState(_state.copyWith(errorMessage: 'Файл удалён'));
  }

  Future<void> clearCacheAndReload() async {
    final service = _ref.read(bookOpenServiceProvider);
    await service.invalidateBookCache(_bookId);
    await loadBook();
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
