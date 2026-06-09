import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../data/book_open_service.dart';
import '../data/parsers/normalized_book.dart';
import '../data/reader_settings_persistence.dart';
import '../domain/reader.dart';

part 'reader_screen.g.dart';

@riverpod
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  @override
  ReaderSettings build() {
    _loadFromPrefs();
    return const ReaderSettings();
  }

  void _loadFromPrefs() {
    ReaderSettingsPersistence.load().then((settings) {
      if (state == const ReaderSettings()) {
        state = settings;
      }
    });
  }

  void _persist() {
    ReaderSettingsPersistence.save(state);
  }

  void updateTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
    _persist();
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
    _persist();
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
    _persist();
  }

  void updateFont(ReaderFont font) {
    state = state.copyWith(font: font);
    _persist();
  }

  void updateParagraphSpacing(double spacing) {
    state = state.copyWith(paragraphSpacing: spacing);
    _persist();
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing);
    _persist();
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
    _persist();
  }
}

@riverpod
class ReadingProgressNotifier extends _$ReadingProgressNotifier {
  @override
  ReadingProgress? build() {
    return null;
  }

  void updateProgress(ReadingProgress progress) {
    state = progress;
  }
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentPage = 0;
  int _currentChapterIndex = 0;
  NormalizedBook? _book;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadBook();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
  }

  Future<void> _loadBook() async {
    try {
      final service = ref.read(bookOpenServiceProvider);
      final book = await service.openBookWithCache(widget.bookId);
      if (!mounted) return;
      final savedChapter = await _loadSavedChapterIndex();
      setState(() {
        _book = book;
        _isLoading = false;
        _currentChapterIndex = savedChapter.clamp(0, book.chapters.length - 1);
      });
      _pageController = PageController(initialPage: _currentChapterIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<int> _loadSavedChapterIndex() async {
    try {
      final db = ref.read(databaseProvider);
      final row = await (db.select(db.readingProgress)
            ..where((t) => t.bookId.equals(widget.bookId)))
          .getSingleOrNull();
      return row?.currentPosition ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saveProgress();
    }
  }

  void _saveProgress() {
    if (_book == null) return;
    final database = ref.read(databaseProvider);
    database.upsertReadingProgress(
      ReadingProgressCompanion.insert(
        bookId: widget.bookId,
        currentPosition: Value(_currentChapterIndex),
        totalPages: Value(_book!.chapters.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = _getThemeData(settings.theme);

    if (_isLoading) {
      return Theme(
        data: theme,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
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
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadBook();
                  },
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
      child: ReaderShortcuts(
        onNextPage: () {
          if (_currentChapterIndex < (_book?.chapters.length ?? 1) - 1) {
            unawaited(
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            );
          }
        },
        onPreviousPage: () {
          if (_currentChapterIndex > 0) {
            unawaited(
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            );
          }
        },
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
              return _buildPhoneReaderLayout(context, settings);
            } else if (width < AppBreakpoints.expanded) {
              return _buildTabletReaderLayout(context, settings);
            } else {
              return _buildDesktopReaderLayout(context, settings);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPhoneReaderLayout(BuildContext context, ReaderSettings settings) {
    return Scaffold(
      appBar: settings.mode == ReaderMode.fullscreen
          ? null
          : (settings.mode == ReaderMode.focus
                ? _buildFocusAppBar(context, settings)
                : AppBar(
                    title: Text('Читалка — ${widget.bookId}'),
                    actions: _buildReaderActions(context, settings),
                  )),
      body: _buildReaderBody(context, settings),
      bottomNavigationBar:
          settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
          ? null
          : _buildReaderBottomNav,
    );
  }

  Widget _buildTabletReaderLayout(BuildContext context, ReaderSettings settings) {
    final maxWidth = 720.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;

    return Scaffold(
      appBar: settings.mode == ReaderMode.fullscreen
          ? null
          : (settings.mode == ReaderMode.focus
                ? _buildFocusAppBar(context, settings)
                : AppBar(
                    title: Text('Читалка — ${widget.bookId}'),
                    actions: _buildReaderActions(context, settings),
                  )),
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding.clamp(0.0, double.infinity)),
        child: _buildReaderBody(context, settings),
      ),
      bottomNavigationBar:
          settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
          ? null
          : _buildReaderBottomNav,
    );
  }

  Widget _buildDesktopReaderLayout(BuildContext context, ReaderSettings settings) {
    final maxWidth = 860.0;
    final horizontalPadding = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
    final sidePanelWidth = 250.0;

    return Scaffold(
      appBar: settings.mode == ReaderMode.fullscreen
          ? null
          : (settings.mode == ReaderMode.focus
                ? _buildFocusAppBar(context, settings)
                : AppBar(
                    title: Text('Читалка — ${widget.bookId}'),
                    actions: _buildReaderActions(context, settings),
                  )),
      body: settings.mode == ReaderMode.fullscreen
          ? _buildFullscreenReaderLayout(context, settings)
          : Row(
              children: [
                Container(
                  width: sidePanelWidth,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Text(
                      'Боковая панель\n(Главы/Закладки/Записки)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding.clamp(0.0, double.infinity),
                    ),
                    child: settings.mode == ReaderMode.twoPage
                        ? _buildTwoPageReaderLayout(context, settings)
                        : _buildReaderBody(context, settings),
                  ),
                ),
              ],
            ),
      bottomNavigationBar:
          settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
          ? null
          : _buildReaderBottomNav,
    );
  }

  PreferredSize _buildFocusAppBar(BuildContext context, ReaderSettings settings) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        title: Text('Читалка — ${widget.bookId}'),
        actions: _buildReaderActions(context, settings),
      ),
    );
  }

  List<Widget> _buildReaderActions(BuildContext context, ReaderSettings settings) {
    return [
      IconButton(
        icon: Icon(_getModeIcon(settings.mode)),
        tooltip: _getModeTooltip(settings.mode),
        onPressed: () {
          final nextMode = _getNextMode(settings.mode);
          ref.read(readerSettingsProvider.notifier).updateMode(nextMode);
        },
      ),
      IconButton(
        icon: Icon(_themeIcon(settings.theme)),
        tooltip: 'Тема',
        onPressed: () => _cycleTheme(ref),
      ),
      _buildFontSizeMenu(settings),
      _buildFontMenu(settings),
      _buildTextAlignMenu(settings),
    ];
  }

  Widget _buildFontSizeMenu(ReaderSettings settings) {
    return PopupMenuButton<double>(
      icon: Text(
        '${settings.fontSize.round()}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      tooltip: 'Размер шрифта',
      onSelected: (double size) {
        ref.read(readerSettingsProvider.notifier).updateFontSize(size);
      },
      itemBuilder: (BuildContext context) {
        return [
          12.0,
          14.0,
          16.0,
          18.0,
          20.0,
          24.0,
          28.0,
          32.0,
        ].map<PopupMenuItem<double>>((double s) {
          return PopupMenuItem<double>(
            value: s,
            child: Text('${s.round()}px'),
          );
        }).toList();
      },
    );
  }

  Widget _buildFontMenu(ReaderSettings settings) {
    return PopupMenuButton<ReaderFont>(
      icon: const Icon(Icons.font_download),
      tooltip: 'Шрифт',
      onSelected: (ReaderFont font) {
        ref.read(readerSettingsProvider.notifier).updateFont(font);
      },
      itemBuilder: (BuildContext context) {
        return ReaderFont.values.map<PopupMenuItem<ReaderFont>>((ReaderFont font) {
          return PopupMenuItem<ReaderFont>(
            value: font,
            child: Text(font.displayName),
          );
        }).toList();
      },
    );
  }

  Widget _buildTextAlignMenu(ReaderSettings settings) {
    return PopupMenuButton<ReaderTextAlign>(
      icon: Icon(_getTextAlignIcon(settings.textAlign)),
      tooltip: 'Выравнивание',
      onSelected: (ReaderTextAlign align) {
        ref.read(readerSettingsProvider.notifier).updateTextAlign(align);
      },
      itemBuilder: (BuildContext context) {
        return ReaderTextAlign.values.map<PopupMenuItem<ReaderTextAlign>>((ReaderTextAlign align) {
          return PopupMenuItem<ReaderTextAlign>(
            value: align,
            child: Row(
              children: [
                Icon(_getTextAlignIcon(align), size: 18),
                const SizedBox(width: 8),
                Text(align.displayName),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  IconData _getTextAlignIcon(ReaderTextAlign align) {
    return switch (align) {
      ReaderTextAlign.left => Icons.format_align_left,
      ReaderTextAlign.justify => Icons.format_align_justify,
      ReaderTextAlign.center => Icons.format_align_center,
      ReaderTextAlign.right => Icons.format_align_right,
    };
  }

  IconData _getModeIcon(ReaderMode mode) {
    return switch (mode) {
      ReaderMode.paginated => Icons.view_carousel,
      ReaderMode.continuous => Icons.view_stream,
      ReaderMode.twoPage => Icons.view_column,
      ReaderMode.focus => Icons.fullscreen,
      ReaderMode.fullscreen => Icons.fullscreen_exit,
    };
  }

  String _getModeTooltip(ReaderMode mode) {
    return switch (mode) {
      ReaderMode.paginated => 'По страницам',
      ReaderMode.continuous => 'Непрерывный',
      ReaderMode.twoPage => 'Две страницы',
      ReaderMode.focus => 'Фокус',
      ReaderMode.fullscreen => 'Полноэкранный',
    };
  }

  ReaderMode _getNextMode(ReaderMode mode) {
    return switch (mode) {
      ReaderMode.paginated => ReaderMode.continuous,
      ReaderMode.continuous => ReaderMode.twoPage,
      ReaderMode.twoPage => ReaderMode.focus,
      ReaderMode.focus => ReaderMode.fullscreen,
      ReaderMode.fullscreen => ReaderMode.paginated,
    };
  }

  static const int _virtualWindow = 1;

  bool _isChapterVisible(int index) {
    return (index - _currentChapterIndex).abs() <= _virtualWindow;
  }

  Widget _buildReaderBody(BuildContext context, ReaderSettings settings) {
    if (_book == null || _book!.chapters.isEmpty) {
      return const Center(child: Text('Нет содержимого'));
    }
    final chapterCount = _book!.chapters.length;
    return SafeArea(
      top: settings.mode != ReaderMode.fullscreen,
      bottom: settings.mode != ReaderMode.fullscreen,
      child: PageView.builder(
        controller: _pageController,
        itemCount: chapterCount,
        onPageChanged: (int page) {
          setState(() {
            _currentChapterIndex = page;
            _currentPage = page;
          });
          ref.read(readingProgressProvider.notifier).updateProgress(
            ReadingProgress(
              bookId: widget.bookId,
              currentPosition: page,
              lastRead: DateTime.now(),
            ),
          );
        },
        itemBuilder: (BuildContext context, int index) {
          if (!_isChapterVisible(index)) {
            return const SizedBox.shrink();
          }
          return _buildChapterPage(context, index, settings);
        },
      ),
    );
  }

  Widget get _buildReaderBottomNav {
    final totalChapters = _book?.chapters.length ?? 0;
    final chapterTitle = _book != null && _currentChapterIndex < totalChapters
        ? _book!.chapters[_currentChapterIndex].title
        : '';
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Гл. ${_currentChapterIndex + 1}/$totalChapters${chapterTitle.isNotEmpty ? ': $chapterTitle' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: _currentChapterIndex > 0
                    ? () {
                        unawaited(
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        );
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: _currentChapterIndex < totalChapters - 1
                    ? () {
                        unawaited(
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenReaderLayout(BuildContext context, ReaderSettings settings) {
    return _buildReaderBody(context, settings);
  }

  Widget _buildTwoPageReaderLayout(BuildContext context, ReaderSettings settings) {
    return _buildReaderBody(context, settings);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      if (_currentChapterIndex > 0) {
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      final max = (_book?.chapters.length ?? 1) - 1;
      if (_currentChapterIndex < max) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
      return true;
    }
    return false;
  }

  Widget _buildChapterPage(
    BuildContext context,
    int chapterIndex,
    ReaderSettings settings,
  ) {
    if (_book == null || chapterIndex < 0 || chapterIndex >= _book!.chapters.length) {
      return const Center(child: Text('Нет содержимого'));
    }

    final chapter = _book!.chapters[chapterIndex];
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(chapterIndex),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final width = MediaQuery.sizeOf(context).width;
            final x = details.localPosition.dx;
            final max = (_book?.chapters.length ?? 1) - 1;
            if (x < width / 3) {
              if (_currentChapterIndex > 0) {
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            } else if (x > width * 2 / 3) {
              if (_currentChapterIndex < max) {
                _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            } else {
              final settings = ref.read(readerSettingsProvider);
              ref.read(readerSettingsProvider.notifier).updateMode(
                settings.mode == ReaderMode.focus ? ReaderMode.continuous : ReaderMode.focus,
              );
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(settings.margin),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chapter.title.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: settings.paragraphSpacing * 2),
                  child: Text(
                    chapter.title,
                    style: _getReaderStyle(settings).copyWith(
                      fontSize: settings.fontSize * 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: textAlign,
                  ),
                ),
              ...chapter.blocks.map((block) => _buildBlock(block, settings, textAlign)),
              if (chapterIndex < _book!.chapters.length - 1)
                Padding(
                  padding: EdgeInsets.only(top: settings.paragraphSpacing * 3),
                  child: Center(
                    child: Text(
                      '— ${_book!.chapters[chapterIndex + 1].title} —',
                      style: _getReaderStyle(settings).copyWith(
                        color: _getReaderStyle(settings).color?.withValues(alpha: 0.4),
                      ),
                      textAlign: textAlign,
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(ReaderBlock block, ReaderSettings settings, TextAlign textAlign) {
    switch (block.type) {
      case BlockType.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: settings.paragraphSpacing * 2,
            bottom: settings.paragraphSpacing,
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 1.2,
              fontWeight: FontWeight.bold,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.quote:
        return Container(
          margin: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getReaderStyle(settings).color!.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.separator:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing * 2),
          child: Center(child: Text('* * *', style: _getReaderStyle(settings))),
        );
      case BlockType.image:
        if (block.imageUrl != null) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
            child: Center(
              child: Icon(Icons.image, size: 64, color: _getReaderStyle(settings).color),
            ),
          );
        }
        return const SizedBox.shrink();
      case BlockType.footnote:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing / 2),
          child: Text(
            block.text,
            style: _getReaderStyle(settings).copyWith(
              fontSize: settings.fontSize * 0.85,
            ),
            textAlign: textAlign,
          ),
        );
      case BlockType.paragraph:
        return Padding(
          padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
          child: Text(
            block.text,
            style: _getReaderStyle(settings),
            textAlign: textAlign,
          ),
        );
    }
  }

  TextStyle _getReaderStyle(ReaderSettings settings) {
    final isDark = settings.theme == ReaderTheme.dark || settings.theme == ReaderTheme.oledBlack;
    final color = isDark ? Colors.white70 : Colors.black87;
    switch (settings.font) {
      case ReaderFont.merriweather:
        return GoogleFonts.merriweather(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: color,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.sourceSerif:
        return GoogleFonts.sourceSerif4(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: color,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.robotoSerif:
        return GoogleFonts.robotoSerif(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: color,
          letterSpacing: settings.letterSpacing,
        );
      case ReaderFont.literata:
        return GoogleFonts.literata(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: color,
          letterSpacing: settings.letterSpacing,
        );
    }
  }

  void _cycleTheme(WidgetRef ref) {
    final current = ref.read(readerSettingsProvider).theme;
    final next = ReaderTheme.values[(current.index + 1) % ReaderTheme.values.length];
    ref.read(readerSettingsProvider.notifier).updateTheme(next);
  }

  IconData _themeIcon(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.light => Icons.light_mode,
      ReaderTheme.dark => Icons.dark_mode,
      ReaderTheme.sepia => Icons.auto_awesome,
      ReaderTheme.oledBlack => Icons.brightness_1,
      ReaderTheme.paper => Icons.description,
    };
  }

  ThemeData _getThemeData(ReaderTheme theme) {
    final base = Theme.of(context);
    return switch (theme) {
      ReaderTheme.light => base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: base.textTheme.apply(bodyColor: Colors.black87),
      ),
      ReaderTheme.dark => base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        textTheme: base.textTheme.apply(bodyColor: Colors.white70),
      ),
      ReaderTheme.sepia => base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4ecd8),
        textTheme: base.textTheme.apply(bodyColor: const Color(0xFF5B4636)),
      ),
      ReaderTheme.oledBlack => base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: base.textTheme.apply(bodyColor: Colors.white70),
      ),
      ReaderTheme.paper => base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F0E6),
        textTheme: base.textTheme.apply(bodyColor: const Color(0xFF3E3225)),
      ),
    };
  }
}
