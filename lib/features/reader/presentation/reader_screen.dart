import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/reader_shortcuts.dart';
import '../domain/reader.dart';

part 'reader_screen.g.dart';

@riverpod
class ReaderSettingsNotifier extends _$ReaderSettingsNotifier {
  @override
  ReaderSettings build() {
    return const ReaderSettings();
  }

  void updateTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme);
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  void updateMode(ReaderMode mode) {
    state = state.copyWith(mode: mode);
  }

  void updateFont(ReaderFont font) {
    state = state.copyWith(font: font);
  }

  void updateParagraphSpacing(double spacing) {
    state = state.copyWith(paragraphSpacing: spacing);
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing);
  }

  void updateTextAlign(ReaderTextAlign align) {
    state = state.copyWith(textAlign: align);
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

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = _getThemeData(settings.theme);

    return Theme(
      data: theme,
      child: ReaderShortcuts(
        onNextPage: () {
          unawaited(
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          );
        },
        onPreviousPage: () {
          if (_currentPage > 0) {
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
      bottomNavigationBar: settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
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
      bottomNavigationBar: settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
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
                    child: Text('Боковая панель\n(Главы/Закладки/Записки)', textAlign: TextAlign.center),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding.clamp(0.0, double.infinity)),
                    child: settings.mode == ReaderMode.twoPage
                        ? _buildTwoPageReaderLayout(context, settings)
                        : _buildReaderBody(context, settings),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: settings.mode == ReaderMode.fullscreen || settings.mode == ReaderMode.focus
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
          12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0,
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

  Widget _buildReaderBody(BuildContext context, ReaderSettings settings) {
    return SafeArea(
      top: settings.mode != ReaderMode.fullscreen,
      bottom: settings.mode != ReaderMode.fullscreen,
      left: true,
      right: true,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
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
          return _buildPage(context, index, settings);
        },
      ),
    );
  }

  Widget get _buildReaderBottomNav {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Стр. ${_currentPage + 1}'),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: _currentPage > 0
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
                onPressed: () {
                  unawaited(
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  );
                },
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

  Widget _buildPage(
    BuildContext context,
    int index,
    ReaderSettings settings,
  ) {
    final isDark = settings.theme == ReaderTheme.dark || settings.theme == ReaderTheme.oledBlack;
    final textAlign = switch (settings.textAlign) {
      ReaderTextAlign.left => TextAlign.left,
      ReaderTextAlign.justify => TextAlign.justify,
      ReaderTextAlign.center => TextAlign.center,
      ReaderTextAlign.right => TextAlign.right,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.all(settings.margin),
      child: Text(
        'Страница ${index + 1}\n\n'
        'Загрузите книгу для чтения.\n\n'
        'Здесь будет отображаться текст книги в формате ${settings.mode.name}.\n\n'
        'Шрифт: ${settings.font.displayName}',
        style: _getReaderStyle(settings),
        textAlign: textAlign,
      ),
    );
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
