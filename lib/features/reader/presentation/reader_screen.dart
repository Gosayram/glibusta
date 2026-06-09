import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/widgets/reader_shortcuts.dart';
import '../domain/reader.dart';

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
        child: Scaffold(
          appBar: AppBar(
            title: Text('Читалка — ${widget.bookId}'),
            actions: [
              IconButton(
                icon: Icon(
                  settings.mode == ReaderMode.paginated ? Icons.view_carousel : Icons.view_stream,
                ),
                tooltip: settings.mode == ReaderMode.paginated ? 'Непрерывный' : 'По страницам',
                onPressed: () {
                  final nextMode = settings.mode == ReaderMode.paginated
                      ? ReaderMode.continuous
                      : ReaderMode.paginated;
                  ref.read(readerSettingsProvider.notifier).state = settings.copyWith(
                    mode: nextMode,
                  );
                },
              ),
              IconButton(
                icon: Icon(_themeIcon(settings.theme)),
                tooltip: 'Тема',
                onPressed: () => _cycleTheme(ref),
              ),
              PopupMenuButton<double>(
                icon: Text(
                  '${settings.fontSize.round()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                tooltip: 'Размер шрифта',
                onSelected: (double size) {
                  ref.read(readerSettingsProvider.notifier).state = settings.copyWith(
                    fontSize: size,
                  );
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
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
              ref.read(readingProgressProvider.notifier).state = ReadingProgress(
                bookId: widget.bookId,
                currentPosition: page,
                lastRead: DateTime.now(),
              );
            },
            itemBuilder: (BuildContext context, int index) {
              return _buildPage(context, index, settings);
            },
          ),
          bottomNavigationBar: BottomAppBar(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Стр. ${_currentPage + 1}'),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    int index,
    ReaderSettings settings,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(settings.margin),
      child: Text(
        'Страница ${index + 1}\n\n'
        'Загрузите книгу для чтения.\n\n'
        'Здесь будет отображаться текст книги в формате ${settings.mode.name}.',
        style: TextStyle(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
        ),
      ),
    );
  }

  void _cycleTheme(WidgetRef ref) {
    final current = ref.read(readerSettingsProvider).theme;
    final next = ReaderTheme.values[(current.index + 1) % ReaderTheme.values.length];
    ref.read(readerSettingsProvider.notifier).state = ref
        .read(readerSettingsProvider)
        .copyWith(theme: next);
  }

  IconData _themeIcon(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.light => Icons.light_mode,
      ReaderTheme.dark => Icons.dark_mode,
      ReaderTheme.sepia => Icons.auto_awesome,
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
    };
  }
}

final readerSettingsProvider = StateProvider<ReaderSettings>((ref) {
  return const ReaderSettings();
});

final readingProgressProvider = StateProvider<ReadingProgress?>((ref) {
  return null;
});
