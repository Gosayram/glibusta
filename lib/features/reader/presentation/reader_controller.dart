import 'dart:async';
import 'dart:collection';
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
import '../../../core/utils/monotonic_id.dart';
import '../../highlights/data/highlight_repository.dart';
import '../../highlights/presentation/highlight_providers.dart';
import '../data/auto_theme_service.dart';
import '../data/book_open_service.dart';
import '../data/book_search_service.dart';
import '../data/parsers/normalized_book.dart';
import '../data/per_book_settings_service.dart';
import '../domain/reader.dart';
import 'reader_content_helper.dart';
import 'reader_corner_tap.dart';
import 'reader_link_history.dart';
import 'reader_progress_helper.dart';
import 'reader_providers.dart';
import 'reader_two_finger_chapter_gesture.dart';

enum HighlightSelectionMode { idle, startSet }

enum ReaderErrorKind {
  bookMissing('Книга не найдена', Icons.search_off),
  unsupportedFormat('Формат не поддерживается', Icons.block),
  parserTimeout('Превышено время ожидания', Icons.hourglass_empty),
  cacheCorrupted('Повреждённый кеш', Icons.broken_image_outlined),
  invalidEncoding('Ошибка кодировки', Icons.text_fields),
  corruptFile('Файл повреждён', Icons.broken_image_outlined),
  missingContent('Отсутствует содержимое', Icons.article_outlined),
  emptyBook('Пустая книга', Icons.menu_book_outlined),
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
  final int searchMatchCount;
  final int searchMatchIndex;
  final bool isDynamicallyLoading;
  final List<double> checkpoints;
  final int wpm;
  final HighlightSelectionMode highlightMode;
  final int? multiHighlightStartChapter;
  final int? multiHighlightStartParagraph;
  final String? multiHighlightStartText;

  // ignore: prefer_const_constructors_in_immutables
  ReaderState({
    this.metadata,
    Map<int, ReaderChapter> loadedChapters = const {},
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
    this.searchMatchCount = 0,
    this.searchMatchIndex = 0,
    this.isDynamicallyLoading = false,
    List<double> checkpoints = const [],
    this.wpm = 200,
    this.highlightMode = HighlightSelectionMode.idle,
    this.multiHighlightStartChapter,
    this.multiHighlightStartParagraph,
    this.multiHighlightStartText,
  }) : loadedChapters = loadedChapters is UnmodifiableMapView
           ? loadedChapters
           : Map.unmodifiable(loadedChapters),
       checkpoints = checkpoints is UnmodifiableListView
           ? checkpoints
           : List.unmodifiable(checkpoints),
       currentPosition = currentPosition ?? ReaderPosition.initial;

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
    bool clearMetadata = false,
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
    int? searchMatchCount,
    int? searchMatchIndex,
    bool clearSearchMatches = false,
    bool clearLoadingMessage = false,
    bool? isDynamicallyLoading,
    List<double>? checkpoints,
    int? wpm,
    HighlightSelectionMode? highlightMode,
    int? multiHighlightStartChapter,
    bool clearMultiHighlightStart = false,
    int? multiHighlightStartParagraph,
    String? multiHighlightStartText,
  }) {
    return ReaderState(
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
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
      searchMatchCount: clearSearchMatches ? 0 : (searchMatchCount ?? this.searchMatchCount),
      searchMatchIndex: clearSearchMatches ? 0 : (searchMatchIndex ?? this.searchMatchIndex),
      isDynamicallyLoading: isDynamicallyLoading ?? this.isDynamicallyLoading,
      checkpoints: checkpoints ?? this.checkpoints,
      wpm: wpm ?? this.wpm,
      highlightMode: highlightMode ?? this.highlightMode,
      multiHighlightStartChapter: clearMultiHighlightStart
          ? null
          : (multiHighlightStartChapter ?? this.multiHighlightStartChapter),
      multiHighlightStartParagraph: clearMultiHighlightStart
          ? null
          : (multiHighlightStartParagraph ?? this.multiHighlightStartParagraph),
      multiHighlightStartText: clearMultiHighlightStart
          ? null
          : (multiHighlightStartText ?? this.multiHighlightStartText),
    );
  }
}

final class ReaderController {
  ReaderController(this._bookId, this._ref)
    : _autoThemeService = _ref.read(autoThemeServiceProvider),
      _logger = _ref.read(appLoggerProvider);

  final String _bookId;
  final Ref _ref;

  final AutoThemeService _autoThemeService;
  final AppLogger _logger;
  final _progressDebouncer = Debouncer(delay: AppDuration.readerProgressSave);
  final _chapterLoadDebouncer = Debouncer(delay: const Duration(milliseconds: 200));
  final _scrollDebouncer = Debouncer(delay: const Duration(milliseconds: 50));
  final _sessionStopwatch = Stopwatch();
  int _accumulatedSeconds = 0;
  int _sessionWordsRead = 0;
  int _estimatedTotalWords = 0;
  bool _paused = false;
  Timer? _hideTimer;
  Timer? _autoThemeTimer;
  Timer? _pageFlushTimer;
  ScrollController? _scrollController;
  ReaderState _state = ReaderState();
  final _stateController = StreamController<ReaderState>.broadcast();
  bool _disposed = false;
  bool _loaded = false;
  List<BookSearchResult> _searchMatches = const [];
  int _searchMatchIndex = 0;
  int _loadGeneration = 0;
  int _chapterLoadGeneration = 0;
  String _cacheMode = 'unknown';
  bool _isLoadingNextChapter = false;
  double _lastScrollOffset = 0;
  final _linkHistory = ReaderLinkHistory();
  List<double> _chapterPositions = const [];
  int _accumulatedPages = 0;

  late final ReaderContentHelper _content;
  ReaderProgressHelper? _progress;

  ReaderState get state => _state;
  Stream<ReaderState> get stateStream => _stateController.stream;

  void dispose() {
    _loadGeneration++;
    _linkHistory.clear();
    _chapterPositions = const [];
    _progressDebouncer.dispose();
    _chapterLoadDebouncer.dispose();
    _scrollDebouncer.dispose();
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    _pageFlushTimer?.cancel();
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _flushSessionTime();
    _flushPages();
    savePosition();
    unawaited(WakelockPlus.disable());
    unawaited(_stateController.close());
    _disposed = true;
  }

  void _flushSessionTime() {
    if (_sessionStopwatch.isRunning) {
      _sessionStopwatch.stop();
    }
    final totalSeconds = _accumulatedSeconds + (_sessionStopwatch.elapsed.inSeconds);
    _accumulatedSeconds = 0;
    _sessionStopwatch.reset();
    if (totalSeconds > 0 && !_disposed) {
      final db = _ref.read(databaseProvider);
      final now = DateTime.now();
      unawaited(db.readingTimeDao.addReadingTime(_bookId, now, totalSeconds));
      if (totalSeconds > 60 && _sessionWordsRead > 0) {
        final wpm = (_sessionWordsRead / totalSeconds * 60).round().clamp(50, 800).toDouble();
        unawaited(db.readingTimeDao.addWpm(_bookId, now, wpm));
      }
    }
  }

  void _flushPages() {
    if (_accumulatedPages <= 0 || _disposed) return;
    final pages = _accumulatedPages;
    _accumulatedPages = 0;
    final db = _ref.read(databaseProvider);
    unawaited(db.readingTimeDao.addPagesRead(_bookId, DateTime.now(), pages));
  }

  void pauseSession() {
    if (_paused || !_loaded) return;
    _paused = true;
    if (_sessionStopwatch.isRunning) {
      _sessionStopwatch.stop();
    }
    _accumulatedSeconds += _sessionStopwatch.elapsed.inSeconds;
    _sessionStopwatch.reset();
    _flushAccumulatedTime();
  }

  void resumeSession() {
    if (!_paused || !_loaded) return;
    _paused = false;
    _sessionStopwatch.start();
  }

  void _flushAccumulatedTime() {
    if (_accumulatedSeconds > 0 && !_disposed) {
      final db = _ref.read(databaseProvider);
      unawaited(
        db.readingTimeDao.addReadingTime(_bookId, DateTime.now(), _accumulatedSeconds),
      );
      _accumulatedSeconds = 0;
    }
  }

  void _updateState(ReaderState newState) {
    if (_disposed) return;
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  // ── Load ──────────────────────────────────────────────

  Future<void> loadBook() async {
    final loadGeneration = ++_loadGeneration;
    _chapterLoadGeneration++;
    _loaded = false;
    _sessionWordsRead = 0;
    _estimatedTotalWords = 0;
    _cacheMode = 'unknown';
    _chapterPositions = const [];
    _hideTimer?.cancel();
    _autoThemeTimer?.cancel();
    _autoThemeTimer = null;
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    _scrollController = null;
    _updateState(
      _state.copyWith(
        clearMetadata: true,
        loadedChapters: const {},
        loadingStage: ReaderLoadingStage.openingFile,
        clearError: true,
        currentPosition: ReaderPosition.initial,
        scrollProgress: 0,
        estimatedMinutesLeft: 0,
        clearHighlight: true,
        isDynamicallyLoading: false,
        checkpoints: const [],
        wpm: 200,
      ),
    );

    final service = _ref.read(bookOpenServiceProvider);
    final db = _ref.read(databaseProvider);
    _content = ReaderContentHelper(service, _bookId, _logger);
    _progress = ReaderProgressHelper(db, _bookId, _logger);

    try {
      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.readingMetadata));
      final meta = await _content.loadMetadata(onCacheMode: (mode) => _cacheMode = mode);
      if (!_isActiveLoad(loadGeneration)) return;

      // Apply per-book settings if available
      await _applyPerBookSettings(deviceClass: _layoutDeviceClass);

      // MD-11.4: auto dark theme for manga/comics
      if (!_isActiveLoad(loadGeneration)) return;
      final settings = _ref.read(readerSettingsProvider);
      if (!settings.eink) {
        _autoMangaTheme(meta);
      }

      // MD-11.3: auto font by genre
      unawaited(_autoGenreFont(_bookId));

      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.loadingChapters));
      final savedPosition = await _progress!.loadSavedPosition(meta.chapterCount);
      if (!_isActiveLoad(loadGeneration)) return;

      _updateState(_state.copyWith(loadingStage: ReaderLoadingStage.loadingChapters));
      _updateState(
        _state.copyWith(
          metadata: meta,
          currentPosition: savedPosition.clamp(chapterCount: meta.chapterCount),
          clearHighlight: true,
        ),
      );

      if (meta.chapterCount == 0) {
        if (!_isActiveLoad(loadGeneration)) return;
        _updateState(
          _state.copyWith(
            clearLoadingStage: true,
            errorKind: ReaderErrorKind.emptyBook,
            errorMessage: BookOpenError.emptyBook.userMessage,
          ),
        );
        return;
      }

      _scrollController?.removeListener(_onScroll);
      _scrollController?.dispose();
      _scrollController = ScrollController()..addListener(_onScroll);

      await _ensureChaptersLoaded(savedPosition.chapterIndex);
      if (!_isActiveLoad(loadGeneration)) return;
      _loaded = true;
      _sessionStopwatch.start();
      _updateState(_state.copyWith(clearLoadingStage: true, clearError: true));

      final loadedWords = _content.computeTotalWords(_state.loadedChapters);
      _sessionWordsRead = loadedWords;
      final loadedCount = _state.loadedChapters.length;
      final totalCount = _state.chapterCount;
      _estimatedTotalWords = loadedCount > 0 && totalCount > loadedCount
          ? (loadedWords / loadedCount * totalCount).round()
          : loadedWords;
      final totalSeconds =
          _accumulatedSeconds +
          (_sessionStopwatch.isRunning ? _sessionStopwatch.elapsed.inSeconds : 0);
      final wpm = totalSeconds > 60 && _sessionWordsRead > 0
          ? (_sessionWordsRead / totalSeconds * 60).round().clamp(50, 800)
          : 200;
      _updateState(
        _state.copyWith(
          estimatedMinutesLeft: _estimateMinutesLeft(
            _progressForPosition(_state.currentPosition),
            wpm: wpm,
          ),
          wpm: wpm,
        ),
      );

      if (settings.restoreLastPosition && savedPosition.progressPercent > 0) {
        _restoreSavedPosition(savedPosition);
      }
      if (!settings.eink) {
        _autoThemeTimer = Timer.periodic(
          AppDuration.autoThemeCheck,
          (_) => _checkAutoTheme(),
        );
      }
      if (settings.mode == ReaderMode.focus) {
        hideUi();
      } else {
        _startHideTimer();
      }
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

  ReaderMode get effectiveMode => _ref.read(readerSettingsProvider).mode;

  static ReaderErrorKind _classifyError(Object error) => switch (error) {
    BookMissingFailure() => ReaderErrorKind.bookMissing,
    UnsupportedFormatFailure() => ReaderErrorKind.unsupportedFormat,
    ParserTimeoutFailure() => ReaderErrorKind.parserTimeout,
    CacheCorruptedFailure() => ReaderErrorKind.cacheCorrupted,
    InvalidEncodingFailure() => ReaderErrorKind.invalidEncoding,
    CorruptFileFailure() => ReaderErrorKind.corruptFile,
    MissingContentFailure() => ReaderErrorKind.missingContent,
    TimeoutException() => ReaderErrorKind.parserTimeout,
    _ => ReaderErrorKind.unknown,
  };

  static String _userFriendlyMessage(Object error, ReaderErrorKind kind) {
    return switch (error) {
      CorruptFileFailure() => BookOpenError.corruptFile.userMessage,
      MissingContentFailure() => BookOpenError.missingContent.userMessage,
      _ => error.toString(),
    };
  }

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
      _logger.warning(
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
        errorMessage: _userFriendlyMessage(e, errorKind),
        errorFilePath: filePath,
        errorFormat: format,
        errorFileSize: fileSize,
      ),
    );
  }

  // ── Chapter windowing ─────────────────────────────────

  /// Called when the paginated reader swipes to a new page.
  /// Triggers chapter loading for the page's chapter + eviction of distant ones.
  void handlePageChanged(int chapterIndex) {
    if (_disposed || _state.chapterCount == 0) return;
    final clamped = chapterIndex.clamp(0, _state.chapterCount - 1);
    final progress = _chapterProgress(clamped);
    if (clamped != _state.currentPosition.chapterIndex) {
      _accumulatedPages++;
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(
            chapterIndex: clamped,
            progressPercent: progress,
          ),
          scrollProgress: progress,
          estimatedMinutesLeft: _estimateMinutesLeft(progress),
        ),
      );
      _pageFlushTimer?.cancel();
      _pageFlushTimer = Timer(const Duration(seconds: 30), _flushPages);
    }
    _chapterLoadDebouncer.call(() {
      if (_disposed) return;
      unawaited(_ensureChaptersLoaded(clamped));
      _evictDistantChapters(clamped);
    });
  }

  /// Records the precise block shown by focus mode so reopening and switching
  /// layouts preserve the paragraph the reader was on.
  void handleFocusPositionChanged(int chapterIndex, int paragraphIndex) {
    if (_disposed || _state.chapterCount == 0) return;
    final clampedChapter = chapterIndex.clamp(0, _state.chapterCount - 1);
    final clampedParagraph = paragraphIndex < 0 ? 0 : paragraphIndex;
    if (clampedChapter == _state.currentPosition.chapterIndex &&
        clampedParagraph == _state.currentPosition.paragraphIndex) {
      return;
    }
    _updateState(
      _state.copyWith(
        currentPosition: _state.currentPosition.copyWith(
          chapterIndex: clampedChapter,
          paragraphIndex: clampedParagraph,
        ),
      ),
    );
    _chapterLoadDebouncer.call(() {
      if (_disposed) return;
      unawaited(_ensureChaptersLoaded(clampedChapter));
      _evictDistantChapters(clampedChapter);
    });
  }

  Future<void> _ensureChaptersLoaded(int centerIndex) async {
    final generation = ++_chapterLoadGeneration;
    if (_loaded && !_state.isLoading) {
      _updateState(_state.copyWith(isDynamicallyLoading: true));
    }
    try {
      final updated = await _content.ensureChaptersLoaded(
        centerIndex,
        _state.loadedChapters,
        chapterCount: _state.chapterCount,
      );
      // Discard stale results if a newer chapter load superseded this one.
      if (_disposed || generation != _chapterLoadGeneration) return;
      // Chapter loading captures the current window before awaiting I/O.  Evict
      // again after that work completes so the captured, now-distant chapters
      // cannot be reintroduced after the eager eviction in [handlePageChanged].
      final windowed = _content.evictDistantChapters(centerIndex, updated);
      _updateState(_state.copyWith(loadedChapters: windowed, isDynamicallyLoading: false));
    } on Object catch (error, stackTrace) {
      if (_disposed || generation != _chapterLoadGeneration) return;
      if (!_loaded) rethrow;
      _logger.warning(
        'Failed to load chapter window around $centerIndex',
        name: 'Reader',
        error: error,
        st: stackTrace,
      );
      _updateState(_state.copyWith(isDynamicallyLoading: false));
    }
  }

  void _evictDistantChapters(int centerIndex) {
    final isContinuous = effectiveMode == ReaderMode.continuous;
    final updated = _content.evictDistantChapters(
      centerIndex,
      _state.loadedChapters,
      keepFrom: isContinuous ? 0 : null,
      keepAllBefore: isContinuous,
    );
    if (updated.length != _state.loadedChapters.length) {
      _updateState(_state.copyWith(loadedChapters: updated));
    }
  }

  Future<void> _loadNextChapter() async {
    if (_disposed || _isLoadingNextChapter || _state.chapterCount == 0) return;
    final loaded = _state.loadedChapters;
    if (loaded.isEmpty) return;
    final lastLoadedIndex = loaded.keys.reduce((a, b) => a > b ? a : b);
    final nextIndex = lastLoadedIndex + 1;
    if (nextIndex >= _state.chapterCount) return;
    if (loaded.containsKey(nextIndex)) return;

    _isLoadingNextChapter = true;
    try {
      final service = _ref.read(bookOpenServiceProvider);
      final chapter = await service.loadChapter(_bookId, nextIndex);
      if (_disposed || chapter == null) return;
      final merged = Map<int, ReaderChapter>.from(_state.loadedChapters);
      merged[nextIndex] = chapter;
      _updateState(_state.copyWith(loadedChapters: merged));
    } on Object catch (e) {
      if (_disposed) return;
      _logger.warning(
        'Seamless scroll: failed to load chapter $nextIndex',
        name: 'Reader',
        error: e,
      );
    } finally {
      _isLoadingNextChapter = false;
    }
  }

  // ── Scroll / progress ─────────────────────────────────

  ScrollController get scrollController {
    if (_disposed) {
      // Avoid creating (and leaking) a fresh controller after disposal;
      // return the existing (disposed) instance when present.
      if (_scrollController != null) return _scrollController!;
    }
    _scrollController ??= ScrollController()..addListener(_onScroll);
    return _scrollController!;
  }

  /// LITHIUM-READ-005: update cached chapter positions from the content body.
  void setChapterPositions(List<double> positions) {
    _chapterPositions = positions;
  }

  /// LITHIUM-READ-005: resolves the chapter at the top of the viewport using
  /// cumulative chapter offsets reported by the content body during build.
  static int resolveChapterAtViewportTop({
    required double scrollOffset,
    required List<double> chapterPositions,
    required int totalChapters,
  }) {
    if (chapterPositions.isEmpty || totalChapters <= 0) return 0;
    var low = 0;
    var high = chapterPositions.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (chapterPositions[mid] <= scrollOffset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low.clamp(0, totalChapters - 1);
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    if (maxScroll > 0) {
      final progress = _scrollController!.offset / maxScroll;
      final boundedProgress = progress.clamp(0.0, 1.0);
      _scrollDebouncer.call(() {
        _updateState(_state.copyWith(scrollProgress: boundedProgress));
        _updatePositionFromScroll(boundedProgress);
      });
      _progressDebouncer.call(saveProgress);

      // Hide bars on fast scroll
      final settings = _ref.read(readerSettingsProvider);
      if (settings.hideBarsOnFastScroll && !settings.eink && _state.uiVisible) {
        final currentOffset = _scrollController!.offset;
        final delta = (currentOffset - _lastScrollOffset).abs();
        _lastScrollOffset = currentOffset;
        if (delta > 30) {
          _updateState(_state.copyWith(uiVisible: false));
        }
      }

      if (!_state.isLoading && _state.chapterCount > 0) {
        final total = _state.chapterCount;
        // LITHIUM-READ-005: viewport-based chapter detection when positions available
        final chapterIndex = _chapterPositions.isNotEmpty
            ? resolveChapterAtViewportTop(
                scrollOffset: _scrollController!.offset,
                chapterPositions: _chapterPositions,
                totalChapters: total,
              )
            : (boundedProgress * (total - 1)).round();
        _chapterLoadDebouncer.call(() {
          if (_disposed) return;
          unawaited(_ensureChaptersLoaded(chapterIndex));
          _evictDistantChapters(chapterIndex);
        });

        // LITHIUM-READ-010: seamless scroll — proactively load next chapter near bottom
        if (effectiveMode == ReaderMode.continuous && !_isLoadingNextChapter) {
          if (_scrollController!.offset > maxScroll * 0.8) {
            unawaited(_loadNextChapter());
          }
        }
      }
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
    final chapterChanged = position.chapterIndex != _state.currentPosition.chapterIndex;
    _updateState(
      _state.copyWith(
        currentPosition: position,
        estimatedMinutesLeft: _estimateMinutesLeft(progress),
      ),
    );
    _ref
        .read(readingProgressProvider.notifier)
        .updateProgress(
          ReadingProgress.fromPosition(position, totalPages: total),
        );
    if (chapterChanged) {
      _accumulatedPages++;
      _pageFlushTimer?.cancel();
      _pageFlushTimer = Timer(const Duration(seconds: 30), _flushPages);
      saveProgress();
    }
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
    final estimate = ReaderContentHelper.estimatePositionFromProgress(
      progress: progress,
      chapterCount: total,
      loadedChapters: _state.loadedChapters,
    );
    // LITHIUM-READ-005: viewport-based chapter detection in continuous mode
    var chapterIndex = estimate.chapterIndex;
    if (effectiveMode == ReaderMode.continuous &&
        _chapterPositions.isNotEmpty &&
        _scrollController != null &&
        _scrollController!.hasClients) {
      chapterIndex = resolveChapterAtViewportTop(
        scrollOffset: _scrollController!.offset,
        chapterPositions: _chapterPositions,
        totalChapters: total,
      );
    }
    return ReaderPosition(
      bookId: _bookId,
      chapterIndex: chapterIndex,
      paragraphIndex: estimate.paragraphIndex,
      localOffset: progress * 100.0,
      progressPercent: progress,
      contentHash: _state.currentPosition.contentHash,
      updatedAt: DateTime.now(),
    );
  }

  double _chapterProgress(int chapterIndex) {
    final lastChapter = _state.chapterCount - 1;
    if (lastChapter <= 0) return 0;
    return (chapterIndex / lastChapter).clamp(0.0, 1.0);
  }

  double _progressForPosition(ReaderPosition position) {
    if (position.progressPercent > 0) return position.progressPercent.clamp(0.0, 1.0);
    return _chapterProgress(position.chapterIndex);
  }

  int _estimateMinutesLeft(double progress, {int? wpm}) {
    if (_estimatedTotalWords <= 0) return 0;
    final remainingWords = (_estimatedTotalWords * (1 - progress.clamp(0.0, 1.0))).ceil();
    if (remainingWords == 0) return 0;
    return (remainingWords / (wpm ?? _state.wpm)).ceil();
  }

  void _restoreSavedPosition(ReaderPosition position) {
    final mode = effectiveMode;
    if (mode == ReaderMode.paginated || mode == ReaderMode.focus) {
      _updateState(_state.copyWith(currentPosition: position));
      return;
    }
    if (_scrollController == null) return;
    _evictDistantChapters(position.chapterIndex);
    unawaited(
      _ensureChaptersLoaded(position.chapterIndex).then((_) {
        if (_disposed || _scrollController == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed || _scrollController == null || !_scrollController!.hasClients) return;
          final maxScroll = _scrollController!.position.maxScrollExtent;
          if (maxScroll <= 0) return;
          unawaited(
            _scrollController!.animateTo(
              _semanticAnchor(position).clamp(0.0, maxScroll) * maxScroll,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          );
        });
      }),
    );
  }

  // CRT-22.1: use stable chapter/paragraph instead of visual progressPercent
  double _semanticAnchor(ReaderPosition position) {
    if (_state.chapterCount <= 1) {
      final chapter = _state.chapterAt(0);
      final count = chapter?.blocks.length ?? 1;
      return (position.paragraphIndex / count).clamp(0.0, 1.0);
    }
    var totalBlocks = 0;
    var blocksBeforeTarget = 0;
    for (var ch = 0; ch < _state.chapterCount; ch++) {
      final chapter = _state.chapterAt(ch);
      final count = chapter?.blocks.length ?? 1;
      if (ch < position.chapterIndex) {
        blocksBeforeTarget += count;
      } else if (ch == position.chapterIndex) {
        blocksBeforeTarget += (position.paragraphIndex).clamp(0, count - 1);
      }
      totalBlocks += count;
    }
    if (totalBlocks <= 0) return 0.0;
    return (blocksBeforeTarget / totalBlocks).clamp(0.0, 1.0);
  }

  void saveProgress() {
    if (!_loaded) return;
    var totalBlocks = 0;
    for (final chapter in _state.loadedChapters.values) {
      totalBlocks += chapter.blocks.length;
    }
    _progress?.saveProgress(_state.currentPosition, totalBlocks);
  }

  void savePosition() {
    if (_state.currentPosition == ReaderPosition.initial) return;
    _progress?.savePosition(_state.currentPosition);
  }

  void saveCheckpoint() {
    final p = _state.scrollProgress;
    final existing = _state.checkpoints;
    // Deduplicate: remove checkpoint within 2% of current position
    final filtered = existing.where((c) => (c - p).abs() > 0.02).toList()
      ..add(p)
      ..sort();
    _updateState(_state.copyWith(checkpoints: filtered));
  }

  void navigateToCheckpoint(double progress) {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    unawaited(
      _scrollController!.animateTo(
        progress.clamp(0.0, 1.0) * maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
    // Remove the checkpoint after navigating to it (single-use)
    final filtered = _state.checkpoints.where((c) => (c - progress).abs() > 0.02).toList();
    _updateState(_state.copyWith(checkpoints: filtered));
  }

  bool get hasCheckpointAhead {
    final p = _state.scrollProgress;
    return _state.checkpoints.any((c) => c > p + 0.02);
  }

  bool get hasCheckpointBehind {
    final p = _state.scrollProgress;
    return _state.checkpoints.any((c) => c < p - 0.02);
  }

  void navigateToNearestCheckpoint({required bool forward}) {
    final p = _state.scrollProgress;
    final sorted = List<double>.from(_state.checkpoints)..sort();
    if (forward) {
      final next = sorted.where((c) => c > p + 0.02).firstOrNull;
      if (next != null) navigateToCheckpoint(next);
    } else {
      final prev = sorted.where((c) => c < p - 0.02).lastOrNull;
      if (prev != null) navigateToCheckpoint(prev);
    }
  }

  void reanchorAfterLayoutChange() {
    if (!_loaded || _scrollController == null || !_scrollController!.hasClients) return;
    final savedPosition = _state.currentPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _scrollController == null || !_scrollController!.hasClients) return;
      final maxScroll = _scrollController!.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      unawaited(
        _scrollController!.animateTo(
          _semanticAnchor(savedPosition).clamp(0.0, maxScroll) * maxScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  /// Prepares the scroll-based layout to restore the current semantic anchor.
  ///
  /// Paginated mode does not continuously update the visual scroll progress, so carrying
  /// that visual value into continuous mode can reopen the book at an unrelated
  /// location. The chapter/paragraph position remains the canonical anchor.
  void prepareForContinuousLayout() {
    if (!_loaded || _state.chapterCount == 0) return;
    _updateState(
      _state.copyWith(scrollProgress: _semanticAnchor(_state.currentPosition)),
    );
  }

  // ── Navigation ────────────────────────────────────────

  /// Moves to the adjacent chapter without treating a reflow chapter as a page.
  ///
  /// This is deliberately independent from [scrollToNext] and
  /// [scrollToPrevious], whose continuous-mode behavior is viewport scrolling.
  void navigateToAdjacentChapter({required TwoFingerChapterDirection direction}) {
    if (_disposed || _state.chapterCount == 0) return;

    final current = _state.currentPosition.chapterIndex;
    final delta = switch (direction) {
      TwoFingerChapterDirection.previous => -1,
      TwoFingerChapterDirection.next => 1,
    };
    final target = (current + delta).clamp(0, _state.chapterCount - 1);
    if (target == current) return;

    final progress = _chapterProgress(target);
    _updateState(
      _state.copyWith(
        currentPosition: _state.currentPosition.copyWith(
          chapterIndex: target,
          paragraphIndex: 0,
          localOffset: 0,
          progressPercent: progress,
        ),
        scrollProgress: progress,
        estimatedMinutesLeft: _estimateMinutesLeft(progress),
      ),
    );
    unawaited(_ensureChaptersLoaded(target));
    _evictDistantChapters(target);

    if (effectiveMode == ReaderMode.continuous) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reanchorAfterLayoutChange());
    }
  }

  void scrollToNext() {
    if (_disposed || _state.chapterCount == 0) return;
    final mode = effectiveMode;
    if (mode == ReaderMode.paginated) {
      final settings = _ref.read(readerSettingsProvider);
      final step = settings.twoPageEnabled ? 2 : 1;
      final nextChapter = (_state.currentPosition.chapterIndex + step).clamp(
        0,
        _state.chapterCount - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(
            chapterIndex: nextChapter,
            progressPercent: _chapterProgress(nextChapter),
          ),
          scrollProgress: _chapterProgress(nextChapter),
          estimatedMinutesLeft: _estimateMinutesLeft(_chapterProgress(nextChapter)),
        ),
      );
      unawaited(_ensureChaptersLoaded(nextChapter));
      _evictDistantChapters(nextChapter);
      return;
    }
    if (mode == ReaderMode.focus) {
      _advanceFocusParagraph(direction: 1);
      return;
    }
    if (mode == ReaderMode.rsvp) return; // RSVP handles its own play/pause
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

  void _advanceFocusParagraph({required int direction}) {
    final ch = _state.currentPosition.chapterIndex;
    final para = _state.currentPosition.paragraphIndex;
    var newCh = ch;
    var newPara = para + direction;

    // Check bounds within current chapter
    final chapter = _state.loadedChapters[ch];
    if (chapter != null) {
      if (newPara < 0 && ch > 0) {
        // Go to previous chapter's last paragraph
        newCh = ch - 1;
        final prev = _state.loadedChapters[newCh];
        newPara = prev != null ? prev.blocks.length - 1 : 0;
      } else if (newPara >= (chapter.blocks.length)) {
        // Go to next chapter's first paragraph
        if (ch + 1 < _state.chapterCount) {
          newCh = ch + 1;
          newPara = 0;
        } else {
          newPara = chapter.blocks.length - 1;
        }
      }
    }

    if (newCh != ch) {
      unawaited(_ensureChaptersLoaded(newCh));
      _evictDistantChapters(newCh);
    }
    _updateState(
      _state.copyWith(
        currentPosition: _state.currentPosition.copyWith(
          chapterIndex: newCh,
          paragraphIndex: newPara,
        ),
      ),
    );
  }

  void scrollToPrevious() {
    if (_disposed || _state.chapterCount == 0) return;
    final mode = effectiveMode;
    if (mode == ReaderMode.paginated) {
      final settings = _ref.read(readerSettingsProvider);
      final step = settings.twoPageEnabled ? 2 : 1;
      final previousChapter = (_state.currentPosition.chapterIndex - step).clamp(
        0,
        _state.chapterCount - 1,
      );
      _updateState(
        _state.copyWith(
          currentPosition: _state.currentPosition.copyWith(
            chapterIndex: previousChapter,
            progressPercent: _chapterProgress(previousChapter),
          ),
          scrollProgress: _chapterProgress(previousChapter),
          estimatedMinutesLeft: _estimateMinutesLeft(_chapterProgress(previousChapter)),
        ),
      );
      unawaited(_ensureChaptersLoaded(previousChapter));
      _evictDistantChapters(previousChapter);
      return;
    }
    if (mode == ReaderMode.focus) {
      _advanceFocusParagraph(direction: -1);
      return;
    }
    if (mode == ReaderMode.rsvp) return; // RSVP handles its own navigation
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
    final mode = effectiveMode;
    if (mode == ReaderMode.paginated || mode == ReaderMode.focus) {
      final progress = _progressForPosition(clamped);
      _updateState(
        _state.copyWith(
          currentPosition: clamped,
          scrollProgress: progress,
          estimatedMinutesLeft: _estimateMinutesLeft(progress),
        ),
      );
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

  /// Applies a navigation target once the book metadata and its initial
  /// chapter window are ready. This keeps navigation from a persisted
  /// bookmark independent of the book's ordinary last-read position.
  Future<void> jumpToPositionWhenReady(ReaderPosition position) async {
    if (_state.isLoading) {
      await stateStream.firstWhere((state) => !state.isLoading);
    }
    if (_disposed || _state.errorMessage != null || _state.chapterCount == 0) return;
    jumpToPosition(position);
  }

  bool get hasLinkBack => _linkHistory.canGoBack;
  bool get hasLinkForward => _linkHistory.canGoForward;

  void pushLinkPosition() {
    _linkHistory.pushOrigin(_state.currentPosition);
  }

  bool popLinkPosition() {
    final position = _linkHistory.goBack(_state.currentPosition);
    if (position == null) return false;
    jumpToPosition(position);
    return true;
  }

  bool forwardLinkPosition() {
    final position = _linkHistory.goForward(_state.currentPosition);
    if (position == null) return false;
    jumpToPosition(position);
    return true;
  }

  void clearLinkBackStack() => _linkHistory.clear();

  void jumpToProgress(double progress) {
    final bounded = progress.clamp(0.0, 1.0);
    final position = _positionFromProgress(bounded);
    _updateState(
      _state.copyWith(currentPosition: position, scrollProgress: bounded),
    );
    unawaited(_ensureChaptersLoaded(position.chapterIndex));
    _evictDistantChapters(position.chapterIndex);
    final mode = effectiveMode;
    if (mode == ReaderMode.paginated || mode == ReaderMode.focus) return;
    if (_scrollController == null || !_scrollController!.hasClients) return;
    final maxScroll = _scrollController!.position.maxScrollExtent;
    unawaited(
      _scrollController!.animateTo(
        (bounded * maxScroll).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _scrollController == null || !_scrollController!.hasClients) return;
      final actualMax = _scrollController!.position.maxScrollExtent;
      if ((actualMax - maxScroll).abs() > 1) {
        final clampedTarget = (bounded * actualMax).clamp(0.0, actualMax);
        final currentOffset = _scrollController!.offset;
        if ((currentOffset - clampedTarget).abs() > 1) {
          unawaited(
            _scrollController!.animateTo(
              clampedTarget,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          );
        }
      }
    });
  }

  // ── Gestures ──────────────────────────────────────────

  void handleTap(TapUpDetails details, Size size) {
    final settings = _ref.read(readerSettingsProvider);
    final cornerAction = cornerTapActionAt(
      settings: settings,
      position: details.localPosition,
      size: size,
    );
    if (cornerAction != null && cornerAction != CornerTapAction.inherit) {
      switch (cornerAction) {
        case CornerTapAction.previousPage:
          scrollToPrevious();
        case CornerTapAction.nextPage:
          scrollToNext();
        case CornerTapAction.toggleUi:
          toggleUi();
        case CornerTapAction.addBookmark:
          addBookmark();
        case CornerTapAction.disabled:
        case CornerTapAction.inherit:
          break;
      }
      return;
    }

    final width = size.width;
    final x = details.localPosition.dx;
    final zoneWidth = (width * settings.tapZoneWidth).clamp(
      48.0,
      double.infinity,
    ); // MD-24.3: 48dp min
    const snapMargin = 20.0; // ponytail: magnetic edge snapping

    // LW-7.2: RTL swap — in manga RTL, left=next, right=prev
    final bookTextDirection = _state.metadata?.metadata?['textDirection'];
    final isRtl =
        settings.textDirection == ReaderTextDirection.rtl ||
        (settings.textDirection == ReaderTextDirection.auto && bookTextDirection == 'rtl');
    final leftAction = isRtl ? scrollToNext : scrollToPrevious;
    final rightAction = isRtl ? scrollToPrevious : scrollToNext;

    if (x < zoneWidth + snapMargin) {
      leftAction();
    } else if (x > width - zoneWidth - snapMargin) {
      rightAction();
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
      case DoubleTapAction.searchInBook:
        toggleSearch();
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

  void handleCornerLongPress(CornerLongPressAction action) {
    switch (action) {
      case CornerLongPressAction.previousPage:
        scrollToPrevious();
      case CornerLongPressAction.nextPage:
        scrollToNext();
      case CornerLongPressAction.toggleUi:
        toggleUi();
      case CornerLongPressAction.addBookmark:
        addBookmark();
      case CornerLongPressAction.disabled:
      case CornerLongPressAction.inherit:
        break;
    }
  }

  // ── UI state ──────────────────────────────────────────

  void toggleUi() {
    _updateState(_state.copyWith(uiVisible: !_state.uiVisible));
    if (_state.uiVisible) _startHideTimer();
  }

  /// Removes reader chrome until the reader explicitly requests it again.
  ///
  /// Focus mode uses this both when a book opens and when the user switches
  /// into the mode, so its reading surface starts without persistent controls.
  void hideUi() {
    _hideTimer?.cancel();
    if (_state.uiVisible) {
      _updateState(_state.copyWith(uiVisible: false));
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_autoHideSuspended) return;
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

  /// Keeps reader chrome visible while a system accessibility service is
  /// navigating it. The caller resumes the ordinary timeout when that service
  /// no longer requests accessible navigation.
  void setAutoHideSuspended(bool suspended) {
    if (_autoHideSuspended == suspended) return;
    _autoHideSuspended = suspended;
    if (suspended) {
      _hideTimer?.cancel();
    } else if (_state.uiVisible && !_state.isBottomSheetOpen) {
      _startHideTimer();
    }
  }

  bool _autoHideSuspended = false;

  void toggleSearch() {
    final shouldOpen = !_state.isSearchOpen;
    _updateState(_state.copyWith(isSearchOpen: shouldOpen, clearHighlight: shouldOpen));
  }

  void closeSearch() {
    _updateState(
      _state.copyWith(isSearchOpen: false, clearHighlight: true, clearSearchMatches: true),
    );
    _searchMatches = const [];
    _searchMatchIndex = 0;
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

  void setSearchMatches(List<BookSearchResult> matches, int currentIndex) {
    _searchMatches = List.unmodifiable(matches);
    _searchMatchIndex = currentIndex.clamp(0, matches.length - 1);
    _updateState(
      _state.copyWith(
        searchMatchCount: matches.length,
        searchMatchIndex: _searchMatchIndex,
      ),
    );
  }

  void nextSearchMatch() {
    if (_searchMatches.isEmpty) return;
    _searchMatchIndex = (_searchMatchIndex + 1) % _searchMatches.length;
    _jumpToSearchMatch();
  }

  void prevSearchMatch() {
    if (_searchMatches.isEmpty) return;
    _searchMatchIndex = (_searchMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    _jumpToSearchMatch();
  }

  void clearSearchHighlight() {
    _searchMatches = const [];
    _searchMatchIndex = 0;
    _updateState(_state.copyWith(clearHighlight: true, clearSearchMatches: true));
  }

  void _jumpToSearchMatch() {
    if (_searchMatches.isEmpty || _searchMatchIndex >= _searchMatches.length) return;
    final match = _searchMatches[_searchMatchIndex];
    _updateState(_state.copyWith(searchMatchIndex: _searchMatchIndex));
    jumpToPosition(
      ReaderPosition(
        bookId: _bookId,
        chapterIndex: match.chapterIndex,
        paragraphIndex: match.paragraphIndex,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ── Theme / system ────────────────────────────────────

  /// Applies the per-book profile for the reader layout currently available
  /// to the window. A later request wins, so a resize while the profile is
  /// loading cannot restore a stale compact/expanded preference.
  Future<void> applyPerBookSettingsForLayout(ReaderLayoutDeviceClass deviceClass) {
    _layoutDeviceClass = deviceClass;
    return _applyPerBookSettings(deviceClass: deviceClass);
  }

  ReaderLayoutDeviceClass? _layoutDeviceClass;
  int _perBookSettingsRequestVersion = 0;

  Future<void> _applyPerBookSettings({ReaderLayoutDeviceClass? deviceClass}) async {
    final requestVersion = ++_perBookSettingsRequestVersion;
    try {
      final service = _ref.read(perBookSettingsServiceProvider);
      final effective = await service.getEffectiveSettings(_bookId, deviceClass: deviceClass);
      if (requestVersion != _perBookSettingsRequestVersion) return;
      _ref.read(readerSettingsProvider.notifier).applyProfile(effective);
    } on Object catch (e) {
      _logger.warning('Failed to apply per-book settings: $e', name: 'Reader', error: e);
    }
  }

  // MD-11.4: auto dark theme for manga — check title/description for keywords
  static final _mangaPattern = RegExp(
    r'manga|манга|комикс|comic|manga\b',
    caseSensitive: false,
  );

  void _autoMangaTheme(NormalizedBookMetadata meta) {
    final settings = _ref.read(readerSettingsProvider);
    if (settings.autoThemeMode != AutoThemeMode.off) return;
    final isCurrentDark =
        settings.theme == ReaderTheme.dark ||
        settings.theme == ReaderTheme.oled ||
        settings.theme == ReaderTheme.bedtime;
    if (isCurrentDark) return;
    final combined = '${meta.title} ${meta.description ?? ''}';
    if (_mangaPattern.hasMatch(combined)) {
      _ref.read(readerSettingsProvider.notifier).updateTheme(ReaderTheme.dark);
    }
  }

  // MD-11.3: auto font by genre — technical/non-fiction → Inter, fiction → Literata
  static final _technicalGenrePattern = RegExp(
    r'техничес|программирован|наук|учебн|справоч|计算机|компьютер|информатик|математик',
    caseSensitive: false,
  );

  Future<void> _autoGenreFont(String bookId) async {
    final settings = _ref.read(readerSettingsProvider);
    if (settings.font != ReaderFont.literata) return; // user chose something else
    try {
      final db = _ref.read(databaseProvider);
      final book = await db.bookDao.getBookById(bookId);
      if (book == null) return;
      final allGenres = await db.genreDao.getAllGenres();
      final genreMap = {for (final g in allGenres) g.id: g.name};
      final names = book.genreIds.map((id) => genreMap[id] ?? id).join(' ');
      if (_technicalGenrePattern.hasMatch(names)) {
        _ref.read(readerSettingsProvider.notifier).updateFont(ReaderFont.inter);
      }
    } on Object catch (e) {
      _logger.warning('Auto genre font failed: $e', name: 'Reader', error: e);
    }
  }

  void _applyWakeLock() {
    final keepAwake = _ref.read(readerSettingsProvider).keepScreenAwake;
    if (keepAwake) {
      unawaited(WakelockPlus.enable());
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  void _checkAutoTheme() {
    if (_disposed) return;
    final settings = _ref.read(readerSettingsProvider);
    if (settings.autoThemeMode == AutoThemeMode.off) return;
    final resolved = _autoThemeService.resolveTheme(
      settings.autoThemeMode,
      settings.theme,
      customDayHour: settings.customDayHour,
      customNightHour: settings.customNightHour,
      nightTheme: settings.nightTheme,
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
    final id = newMonotonicId();
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
    if (!_isAppOwnedPath(filePath)) {
      _logger.warning(
        'Refusing to delete non-app path: $filePath',
        name: 'Reader',
      );
      return;
    }
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      if (_loaded) {
        await _progress?.deleteDownload();
        await _progress?.deleteProgress();
      }
    } on Object catch (e) {
      _logger.warning('Error during file deletion: $e', name: 'Reader', error: e);
    }
    _updateState(_state.copyWith(errorMessage: 'Файл удалён'));
  }

  static bool _isAppOwnedPath(String path) {
    return path.contains('glibusta');
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
    buffer.writeln('Error kind: ${_state.errorKind?.name ?? "none"}');
    buffer.writeln('File: ${_state.errorFilePath ?? "unknown"}');
    buffer.writeln('Format: ${_state.errorFormat ?? "unknown"}');
    buffer.writeln(
      'Size: ${_state.errorFileSize != null ? "${(_state.errorFileSize! / 1024).toStringAsFixed(1)} KB" : "unknown"}',
    );
    buffer.writeln('Chapters: ${_state.chapterCount}');
    buffer.writeln('Loaded chapters: ${_state.loadedChapters.length}');
    buffer.writeln('Missing chapters: ${_missingChapterCount()}');
    buffer.writeln('Cache mode: $_cacheMode');
    buffer.writeln(
      'Current position: ch${_state.currentPosition.chapterIndex}, p${_state.currentPosition.paragraphIndex}',
    );
    buffer.writeln('Scroll progress: ${(_state.scrollProgress * 100).toStringAsFixed(1)}%');
    buffer.writeln('Loading stage: ${_state.loadingStage?.name ?? "ready"}');
    buffer.writeln('Dynamic loading: ${_state.isDynamicallyLoading}');
    buffer.writeln('Estimated minutes left: ${_state.estimatedMinutesLeft}');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Time: ${DateTime.now().toIso8601String()}');
    return buffer.toString();
  }

  int _missingChapterCount() {
    if (_state.chapterCount == 0) return 0;
    var missing = 0;
    for (var i = 0; i < _state.chapterCount; i++) {
      if (!_state.loadedChapters.containsKey(i)) missing++;
    }
    return missing;
  }

  void copyDiagnostics() {
    final diagnostics = buildDiagnostics();
    unawaited(Clipboard.setData(ClipboardData(text: diagnostics)));
  }

  // CRT-10.7: search highlights
  Future<void> searchHighlights(BuildContext context) async {
    if (!_loaded || _disposed) return;
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => _HighlightSearchDialog(bookId: _bookId),
    );
    if (query == null || query.trim().isEmpty || _disposed || !context.mounted) return;
    final repo = _ref.read(highlightRepositoryProvider);
    final results = await repo.searchHighlights(_bookId, query.trim());
    if (_disposed || !context.mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выделений не найдено'), duration: Duration(seconds: 1)),
      );
      return;
    }
    // Jump to first result
    final first = results.first;
    jumpToPosition(
      ReaderPosition(
        bookId: _bookId,
        chapterIndex: first.chapterIndex,
        paragraphIndex: first.blockIndex,
        progressPercent: _state.chapterCount > 1
            ? first.chapterIndex / (_state.chapterCount - 1)
            : 0.0,
        updatedAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Найдено ${results.length} выделений'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void setMultiHighlightStart(
    int chapterIndex,
    int paragraphIndex,
    String selectedText,
  ) {
    _updateState(
      _state.copyWith(
        highlightMode: HighlightSelectionMode.startSet,
        multiHighlightStartChapter: chapterIndex,
        multiHighlightStartParagraph: paragraphIndex,
        multiHighlightStartText: selectedText,
      ),
    );
  }

  void cancelMultiHighlight() {
    _updateState(
      _state.copyWith(
        highlightMode: HighlightSelectionMode.idle,
        clearMultiHighlightStart: true,
      ),
    );
  }

  Future<void> finishMultiHighlight({
    required String bookId,
    required int endChapterIndex,
    required int endParagraphIndex,
    required String endSelectedText,
  }) async {
    final startChapter = _state.multiHighlightStartChapter;
    final startParagraph = _state.multiHighlightStartParagraph;
    final startText = _state.multiHighlightStartText;
    if (startChapter == null || startParagraph == null || startText == null) return;
    final combinedText = '$startText\n\n$endSelectedText';
    final repo = _ref.read(highlightRepositoryProvider);
    try {
      await repo.saveHighlight(
        bookId: bookId,
        chapterId: startChapter.toString(),
        chapterIndex: startChapter,
        blockIndex: startParagraph,
        startOffset: 0,
        endOffset: combinedText.length,
        selectedText: combinedText,
        color: 'yellow',
      );
    } on HighlightValidationException {
      return;
    }
    cancelMultiHighlight();
  }
}

final readerControllerProvider = Provider.autoDispose.family<ReaderController, String>((
  ref,
  bookId,
) {
  final controller = ReaderController(bookId, ref);
  unawaited(controller.loadBook());
  ref.onDispose(controller.dispose);
  return controller;
});

class _HighlightSearchDialog extends StatefulWidget {
  const _HighlightSearchDialog({required this.bookId});
  final String bookId;

  @override
  State<_HighlightSearchDialog> createState() => _HighlightSearchDialogState();
}

class _HighlightSearchDialogState extends State<_HighlightSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Поиск выделений'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Введите текст...',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Найти'),
        ),
      ],
    );
  }
}
