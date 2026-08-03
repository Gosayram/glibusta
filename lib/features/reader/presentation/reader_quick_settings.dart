import 'dart:async';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/fonts/custom_font_helper.dart';
import '../../../core/platform/adaptive_context.dart';
import '../data/color_preset_service.dart';
import '../data/per_book_settings_service.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'color_preset_provider.dart';
import 'reader_custom_css_editor.dart';
import 'reader_providers.dart';
import 'reader_typography_provider.dart';
import 'reading_break_reminder.dart';

class _TypographyPreset {
  const _TypographyPreset(
    this.name,
    this.font,
    this.fontSize,
    this.lineHeight,
    this.margin,
    this.paragraphSpacing,
    this.paragraphFirstLineIndent,
    this.textAlign,
    this.theme,
  );
  final String name;
  final ReaderFont font;
  final int fontSize;
  final double lineHeight;
  final double margin;
  final double paragraphSpacing;
  final double paragraphFirstLineIndent;
  final ReaderTextAlign textAlign;
  final ReaderTheme theme;
}

class ReaderQuickSettingsSheet extends ConsumerStatefulWidget {
  const ReaderQuickSettingsSheet({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<ReaderQuickSettingsSheet> createState() => _ReaderQuickSettingsSheetState();
}

class _ReaderQuickSettingsSheetState extends ConsumerState<ReaderQuickSettingsSheet> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const _pageLabels = ['Внешний вид', 'Режим', 'Жесты'];

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
    final notifier = ref.read(readerSettingsProvider.notifier);
    final isEink = settings.eink;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isEink ? Colors.white : theme.colorScheme.surface,
        borderRadius: isEink ? null : const BorderRadius.vertical(top: Radius.circular(16)),
        border: isEink ? const Border(top: BorderSide()) : null,
      ),
      padding: const EdgeInsets.only(top: 12),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: TextStyle(
            color: isEink ? Colors.black : theme.textTheme.bodyMedium?.color,
            fontSize: theme.textTheme.bodyMedium?.fontSize,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isEink
                        ? Colors.black54
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(isEink ? 0 : 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildPageIndicator(context, isEink: isEink),
              const SizedBox(height: 8),
              if (widget.bookId != null) ...[
                _buildPerBookSection(context, ref, widget.bookId!, settings),
                _buildPerBookTypographySection(context, ref, widget.bookId!, settings),
              ],
              SizedBox(
                height: _estimatedPageHeight(context),
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildPage1(context, settings, notifier, isEink: isEink),
                    _buildPage2(context, settings, notifier, isEink: isEink),
                    _buildPage3(context, settings, notifier, isEink: isEink),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  double _estimatedPageHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return screenH * 0.5;
  }

  Widget _buildPageIndicator(BuildContext context, {bool isEink = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageLabels.length, (i) {
        final isActive = i == _currentPage;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEink
                  ? (isActive ? Colors.black : Colors.white)
                  : (isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(isEink ? 0 : 16),
              border: isEink ? Border.all() : null,
            ),
            child: Text(
              _pageLabels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isEink
                    ? (isActive ? Colors.white : Colors.black)
                    : (isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Page 1: Внешний вид (Display) ──

  Widget _buildPage1(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Пресеты')),
            IconButton(
              key: const ValueKey('reset-typography-settings'),
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Сбросить настройки типографики',
              onPressed: notifier.resetTypography,
            ),
          ],
        ),
        _buildPresetRow(settings, notifier, isEink: isEink),
        const SizedBox(height: 16),
        const _SectionTitle('Тема контента'),
        _buildThemeRow(context, settings, notifier, isEink: isEink),
        const SizedBox(height: 8),
        const _SectionTitle('Тема интерфейса'),
        _buildUiThemeRow(context, settings, notifier, isEink: isEink),
        const SizedBox(height: 8),
        _buildColorPresetRow(context, ref, settings, notifier, isEink: isEink),
        const SizedBox(height: 12),
        const _SectionTitle('Текстура фона'),
        _buildBackgroundStyleRow(context, settings, notifier, isEink: isEink),
        const SizedBox(height: 12),
        _buildToggleRow(
          'E-ink режим',
          Icons.auto_awesome,
          settings.eink,
          (v) => notifier.updateEink(v),
          isEink: isEink,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Шрифт'),
        _buildFontRow(settings, notifier),
        _buildCustomFontTile(context, ref, settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Размер шрифта'),
        _buildFontSizeRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Размер шрифта заметок'),
        _buildNoteFontSizeRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Толщина шрифта'),
        _buildFontWeightRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Межстрочный'),
        _buildLineHeightRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Выравнивание'),
        _buildTextAlignRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Межбуквенный интервал'),
        _buildSliderRow(
          'Шаг',
          (settings.letterSpacing + 0.5) / 1.0,
          0.0,
          1.0,
          (v) => notifier.updateLetterSpacing(v * 1.0 - 0.5),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Межсловный интервал'),
        _buildSliderRow(
          'Шаг',
          (settings.wordSpacing + 2.0) / 4.0,
          0.0,
          1.0,
          (v) => notifier.updateWordSpacing(v * 4.0 - 2.0),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Отступ абзацев'),
        _buildParagraphIndentModeRow(settings, notifier),
        const SizedBox(height: 8),
        if (settings.paragraphIndentMode != ParagraphIndentMode.emptyLine) ...[
          _buildSliderRow(
            'Шаг',
            settings.paragraphFirstLineIndent / 64.0,
            0.0,
            1.0,
            (v) => notifier.updateParagraphFirstLineIndent(v * 64.0),
          ),
        ],
        const SizedBox(height: 12),
        const _SectionTitle('Интервал между абзацами'),
        _buildSliderRow(
          'px',
          settings.paragraphSpacing / 64.0,
          0.0,
          1.0,
          (v) => notifier.updateParagraphSpacing(v * 64.0),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Отступы'),
        _buildMarginRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Яркость'),
        _buildBrightnessRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Тёплый фильтр'),
        _buildWarmthRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Ширина читателя'),
        _buildReaderWidthRow(settings, notifier),
        const SizedBox(height: 16),
        _buildToggleRow(
          'Показывать изображения',
          Icons.image,
          settings.showImages,
          (v) => notifier.updateShowImages(v),
          isEink: isEink,
        ),
        if (settings.showImages) ...[
          const SizedBox(height: 8),
          _buildSliderRow(
            'Скругление',
            settings.imageCornerRadius / 32,
            0.0,
            1.0,
            (v) => notifier.updateImageCornerRadius(v * 32),
          ),
          _buildSliderRow(
            'Ширина',
            settings.imageWidth,
            0.3,
            1.0,
            (v) => notifier.updateImageWidth(v),
          ),
          const _SectionTitle('Выравнивание'),
          _buildImageAlignmentRow(settings, notifier),
          const SizedBox(height: 8),
          const _SectionTitle('Цветовой эффект'),
          _buildImageColorEffectRow(settings, notifier),
        ],
      ],
    );
  }

  // ── Page 2: Режим (Mode) ──

  Widget _buildPage2(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const _SectionTitle('Режим чтения'),
        _enumChoiceChips(
          current: settings.mode,
          labels: const {
            ReaderMode.paginated: 'Страницы',
            ReaderMode.continuous: 'Прокрутка',
            ReaderMode.focus: 'Фокус',
            ReaderMode.rsvp: 'RSVP',
          },
          onChanged: (v) => notifier.updateMode(v),
        ),
        if (settings.mode == ReaderMode.paginated) ...[
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final canTwoPage = context.canUseTwoPageMode;
              if (!canTwoPage) return const SizedBox.shrink();
              return _buildToggleRow(
                'Две колонки',
                Icons.view_column,
                settings.twoPageEnabled,
                (enabled) => unawaited(
                  _updateTwoPagePreference(
                    context: context,
                    notifier: notifier,
                    enabled: enabled,
                  ),
                ),
                isEink: isEink,
              );
            },
          ),
        ],
        if (settings.mode == ReaderMode.rsvp) ...[
          const SizedBox(height: 12),
          _buildSliderRow(
            'Скорость (слов/мин)',
            (settings.rsvpWpm - 100) / 900,
            0.0,
            1.0,
            (v) => notifier.updateRsvpWpm((v * 900 + 100).round()),
          ),
        ],
        const SizedBox(height: 16),
        const _SectionTitle('Текст и переносы'),
        _buildTextDirectionRow(settings, notifier),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Переносы слов',
          Icons.format_textdirection_l_to_r,
          settings.hyphenation,
          (v) => notifier.updateHyphenation(v),
          isEink: isEink,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          'Старинные цифры',
          Icons.numbers,
          settings.oldStyleFigures,
          (v) => notifier.updateOldStyleFigures(v),
          isEink: isEink,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          'Капители',
          Icons.text_fields,
          settings.smallCaps,
          (v) => notifier.updateSmallCaps(v),
          isEink: isEink,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Анимация страниц'),
        _buildPageTurnAnimationRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Авто-тема'),
        _buildAutoThemeRow(settings, notifier),
        const SizedBox(height: 16),
        _buildToggleRow(
          'Не выключать экран',
          Icons.screen_lock_portrait,
          settings.keepScreenAwake,
          (v) => notifier.updateKeepScreenAwake(v),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Кодировка'),
        _buildEncodingRow(settings, notifier),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Восстанавливать позицию',
          Icons.restore,
          settings.restoreLastPosition,
          (v) => notifier.updateRestoreLastPosition(v),
          isEink: isEink,
        ),
      ],
    );
  }

  Future<void> _updateTwoPagePreference({
    required BuildContext context,
    required ReaderSettingsNotifier notifier,
    required bool enabled,
  }) async {
    final bookId = widget.bookId;
    if (bookId == null) {
      notifier.updateTwoPageEnabled(enabled);
      return;
    }

    notifier.applyPerBookTwoPageEnabled(enabled);
    try {
      await ref
          .read(perBookSettingsServiceProvider)
          .saveTwoPageLayoutPreference(
            bookId: bookId,
            deviceClass: readerLayoutDeviceClassFor(
              canUseTwoPageMode: context.canUseTwoPageMode,
            ),
            enabled: enabled,
          );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to save the per-book two-page preference',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Page 3: Жесты (Gestures & behavior) ──

  Widget _buildPage3(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const _SectionTitle('Панели чтения'),
        _buildToggleRow(
          'Информация сверху',
          Icons.info_outline,
          settings.showTopInfoBar,
          (v) => notifier.updateShowTopInfoBar(v),
          isEink: isEink,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          'Панель инструментов',
          Icons.tune,
          settings.showTopToolbar,
          (v) => notifier.updateShowTopToolbar(v),
          isEink: isEink,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          'Нижняя панель',
          Icons.vertical_align_bottom,
          settings.showBottomBar,
          (v) => notifier.updateShowBottomBar(v),
          isEink: isEink,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Горизонтальный жест'),
        _buildHorizontalGestureRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Чувствительность свайпа'),
        _buildHorizontalGestureScrollRow(settings, notifier),
        const SizedBox(height: 16),
        _buildToggleRow(
          'Вертикальный свайп: яркость и теплота',
          Icons.swipe_up,
          settings.verticalSwipeBrightness,
          (v) => notifier.updateVerticalSwipeBrightness(v),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Тактильный отклик при перелистывании',
          Icons.vibration,
          settings.pageTurnHaptic,
          (v) => notifier.updatePageTurnHaptic(v),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Расширитель восприятия',
          Icons.view_sidebar_outlined,
          settings.perceptionExpander,
          (v) => notifier.updatePerceptionExpander(v),
          isEink: isEink,
        ),
        const SizedBox(height: 12),

        _buildToggleRow(
          'Горизонтальный лимитер',
          Icons.center_focus_strong,
          settings.horizontalLimiter,
          (v) => notifier.updateHorizontalLimiter(v),
          isEink: isEink,
        ),
        if (settings.horizontalLimiter) ...[
          const SizedBox(height: 8),
          _buildSliderRow(
            'Высота зоны',
            settings.horizontalLimiterHeight,
            0.2,
            0.9,
            (v) => notifier.updateHorizontalLimiterHeight(v),
          ),
          _buildSliderRow(
            'Смещение',
            settings.horizontalLimiterOffset,
            0.1,
            0.9,
            (v) => notifier.updateHorizontalLimiterOffset(v),
          ),
          _buildSliderRow(
            'Затемнение',
            settings.horizontalLimiterDimming,
            0.0,
            0.5,
            (v) => notifier.updateHorizontalLimiterDimming(v),
          ),
          _buildToggleRow(
            'Линии-разделители',
            Icons.horizontal_rule,
            settings.horizontalLimiterLines,
            (v) => notifier.updateHorizontalLimiterLines(v),
            isEink: isEink,
          ),
        ],
        const SizedBox(height: 12),

        _buildToggleRow(
          'Bionic Reading',
          Icons.speed,
          settings.bionicReading,
          (v) => notifier.updateBionicReading(v),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Полоса прокрутки',
          Icons.view_sidebar_outlined,
          settings.scrollbarIndicator,
          (v) => notifier.updateScrollbarIndicator(v),
          isEink: isEink,
        ),
        if (settings.mode == ReaderMode.continuous) ...[
          const SizedBox(height: 12),
          _buildToggleRow(
            'Привязка к границам глав',
            Icons.swap_vert,
            settings.scrollSnap,
            (v) => notifier.updateScrollSnap(v),
            isEink: isEink,
          ),
        ],
        const SizedBox(height: 12),
        _buildToggleRow(
          'Скрытие панелей при прокрутке',
          Icons.speed,
          settings.hideBarsOnFastScroll,
          (v) => notifier.updateHideBarsOnFastScroll(v),
          isEink: isEink,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Ориентация экрана'),
        _buildOrientationLockRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Двойной тап'),
        _buildDoubleTapActionRow(settings, notifier),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Два пальца: главы и назад',
          Icons.swipe_vertical,
          settings.twoFingerChapterNavigation,
          (enabled) => notifier.updateTwoFingerChapterNavigation(enabled),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Кнопки громкости: листание',
          Icons.volume_up,
          settings.volumeButtonsEnabled,
          (enabled) => notifier.updateVolumeButtonsEnabled(enabled),
          isEink: isEink,
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Долгое нажатие'),
        _buildLongPressActionRow(settings, notifier),
        const SizedBox(height: 16),
        _buildCornerTapMap(settings, notifier),
        const SizedBox(height: 16),
        _buildCornerLongPressMap(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Скрытие UI (сек)'),
        _buildAutoHideRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Позиция прогресса'),
        _buildProgressBarPositionRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Нижняя панель'),
        _buildBottomBarContentRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Забота о глазах'),
        _buildReadingBreakReminderSettings(isEink: isEink),
        const SizedBox(height: 16),
        // LW-10.1: Custom CSS editor
        ReaderCustomCssEditor(css: settings.customCss, onChanged: notifier.updateCustomCss),
        const SizedBox(height: 12),
        // LW-10.3: Ignore book CSS overrides
        _buildToggleRow(
          'Игнорировать выравнивание книги',
          Icons.format_align_left,
          settings.ignoreBookAlignment,
          (v) => notifier.updateIgnoreBookAlignment(v),
          isEink: isEink,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          'Игнорировать отступы книги',
          Icons.format_indent_increase,
          settings.ignoreBookIndent,
          (v) => notifier.updateIgnoreBookIndent(v),
          isEink: isEink,
        ),
      ],
    );
  }

  Widget _buildReadingBreakReminderSettings({bool isEink = false}) {
    final controller = ref.watch(readingBreakReminderControllerProvider);
    final reminderSettings = controller.state.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToggleRow(
          'Напомнить сделать паузу (эта сессия)',
          Icons.visibility_outlined,
          reminderSettings.enabled,
          (enabled) => setState(
            () => controller.configure(reminderSettings.copyWith(enabled: enabled)),
          ),
          isEink: isEink,
        ),
        if (reminderSettings.enabled)
          DropdownButton<ReadingBreakInterval>(
            value: reminderSettings.interval,
            isExpanded: true,
            items: [
              for (final interval in ReadingBreakInterval.values)
                DropdownMenuItem(
                  value: interval,
                  child: Text('Каждые ${interval.duration.inMinutes} минут'),
                ),
            ],
            onChanged: (interval) {
              if (interval == null) return;
              setState(() => controller.configure(reminderSettings.copyWith(interval: interval)));
            },
          ),
      ],
    );
  }

  // ── Typography presets ──

  static Widget _buildPresetRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    const presets = <_TypographyPreset>[
      _TypographyPreset(
        'Классика',
        ReaderFont.literata,
        18,
        1.6,
        20,
        20,
        0,
        ReaderTextAlign.justify,
        ReaderTheme.sepia,
      ),
      _TypographyPreset(
        'Компактно',
        ReaderFont.inter,
        14,
        1.3,
        12,
        14,
        0,
        ReaderTextAlign.left,
        ReaderTheme.light,
      ),
      _TypographyPreset(
        'Комфортно',
        ReaderFont.literata,
        22,
        1.8,
        24,
        24,
        16,
        ReaderTextAlign.justify,
        ReaderTheme.paper,
      ),
      _TypographyPreset(
        'Минимализм',
        ReaderFont.system,
        16,
        1.5,
        16,
        18,
        0,
        ReaderTextAlign.left,
        ReaderTheme.system,
      ),
    ];

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = presets[i];
          final active =
              settings.font == p.font &&
              settings.fontSize.round() == p.fontSize &&
              settings.lineHeight == p.lineHeight;
          return GestureDetector(
            onTap: () => notifier.applyTypographyPreset(
              font: p.font,
              fontSize: p.fontSize,
              lineHeight: p.lineHeight,
              margin: p.margin,
              paragraphSpacing: p.paragraphSpacing,
              paragraphFirstLineIndent: p.paragraphFirstLineIndent,
              textAlign: p.textAlign,
              theme: p.theme,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEink
                    ? (active ? Colors.black : Colors.white)
                    : (active
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(isEink ? 0 : 12),
                border: Border.all(
                  color: isEink
                      ? Colors.black
                      : (active
                            ? Colors.blue.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.15)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isEink
                          ? (active ? Colors.white : Colors.black)
                          : (active ? Colors.blue : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aa ${p.fontSize}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: p.font.fontFamily,
                      color: isEink
                          ? (active ? Colors.white70 : Colors.black54)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Shared builders ──

  static Widget _buildThemeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderTheme.values.map((theme) {
        final isSelected = settings.theme == theme;
        final colors = ReaderColors.forThemeWithContext(theme, brightness);
        final preview = colors.preview;
        return Semantics(
          button: true,
          selected: isSelected,
          label: '${theme.displayName}. ${preview.semanticLabel}',
          hint: 'Двойное касание для выбора темы.',
          excludeSemantics: true,
          child: Tooltip(
            message: '${theme.displayName}\n${preview.semanticLabel}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => notifier.updateTheme(theme),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.scaffold,
                    borderRadius: BorderRadius.circular(isEink ? 0 : 8),
                    border: Border.all(
                      color: isEink
                          ? Colors.black
                          : (isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color: isEink ? Colors.black : colors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Widget _buildBackgroundStyleRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BackgroundStyle.values.map((style) {
        final isSelected = settings.backgroundStyle == style;
        final preview = _backgroundStylePreview(style);
        return Semantics(
          button: true,
          selected: isSelected,
          label: style.displayName,
          hint: 'Двойное касание для выбора текстуры фона.',
          excludeSemantics: true,
          child: Tooltip(
            message: style.displayName,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => notifier.updateBackgroundStyle(style),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: preview,
                    borderRadius: BorderRadius.circular(isEink ? 0 : 8),
                    border: Border.all(
                      color: isEink
                          ? Colors.black
                          : (isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        color:
                            settings.theme == ReaderTheme.dark ||
                                settings.theme == ReaderTheme.oled ||
                                settings.theme == ReaderTheme.bedtime
                            ? Colors.white70
                            : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static Gradient? _backgroundStylePreview(BackgroundStyle style) {
    return switch (style) {
      BackgroundStyle.solid => null,
      BackgroundStyle.paper => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8F4EC), Color(0xFFF0EBE0)],
      ),
      BackgroundStyle.parchment => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8D5B7), Color(0xFFD4BC94)],
      ),
      BackgroundStyle.darkPaper => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A2725), Color(0xFF1E1C1A)],
      ),
      BackgroundStyle.warmSepia => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF0E0C0), Color(0xFFE0D0A8)],
      ),
    };
  }

  static Widget _buildUiThemeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isSynced = settings.uiTheme == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isSynced ? Icons.link : Icons.link_off,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => notifier.updateUiTheme(isSynced ? settings.theme : null),
              child: Text(
                isSynced ? 'Синхронизировано с контентом' : 'Настроить отдельно',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: isSynced ? 0.4 : 1.0,
          child: IgnorePointer(
            ignoring: isSynced,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReaderTheme.values.map((theme) {
                final current = settings.effectiveUiTheme;
                final isSelected = current == theme;
                final colors = ReaderColors.forThemeWithContext(theme, brightness);
                final preview = colors.preview;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${theme.displayName}. ${preview.semanticLabel}',
                  hint: 'Двойное касание для выбора темы интерфейса.',
                  excludeSemantics: true,
                  child: Tooltip(
                    message: '${theme.displayName}\n${preview.semanticLabel}',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => notifier.updateUiTheme(theme),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.scaffold,
                            borderRadius: BorderRadius.circular(isEink ? 0 : 8),
                            border: Border.all(
                              color: isEink
                                  ? Colors.black
                                  : (isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outline.withValues(alpha: 0.3)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: isEink ? Colors.black : colors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPresetRow(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    bool isEink = false,
  }) {
    final presetsAsync = ref.watch(colorPresetListProvider);
    return presetsAsync.when(
      data: (presets) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isSelected = settings.activeColorPresetId == preset.id;
                final preview = ReaderColorPreview.fromColors(
                  background: preset.backgroundColor,
                  text: preset.fontColor,
                  link: ReaderColors.forTheme(settings.theme).link,
                );
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${preset.name}. ${preview.semanticLabel}',
                  hint: 'Двойное касание для выбора. Долгое нажатие для редактирования.',
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    onTap: () => notifier.updateActiveColorPresetId(preset.id),
                    onLongPress: () => _showColorPresetEditor(
                      context,
                      ref,
                      preset,
                      notifier,
                    ),
                    child: Tooltip(
                      message: '${preset.name}\n${preview.semanticLabel}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: preset.backgroundColor,
                          borderRadius: BorderRadius.circular(isEink ? 0 : 8),
                          border: Border.all(
                            color: isEink
                                ? Colors.black
                                : (isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outline.withValues(alpha: 0.3)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: preset.fontColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showColorPresetEditor(context, ref, null, notifier),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Добавить / Долгое нажатие — редактировать',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showColorPresetEditor(
    BuildContext context,
    WidgetRef ref,
    ColorPreset? existing,
    ReaderSettingsNotifier notifier,
  ) {
    var bgColor = existing?.backgroundColor ?? Colors.white;
    var fgColor = existing?.fontColor ?? Colors.black87;
    var linkColor = existing?.linkColor ?? Colors.blue.shade700;
    var highlightColor = existing?.highlightColor ?? const Color(0x40FFEB3B);
    final nameController = TextEditingController(text: existing?.name ?? '');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(existing != null ? 'Редактировать' : 'Новый пресет'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 16),
                  _buildColorPickerRow(
                    ctx,
                    'Фон',
                    bgColor,
                    (c) => setDialogState(() => bgColor = c),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPickerRow(
                    ctx,
                    'Текст',
                    fgColor,
                    (c) => setDialogState(() => fgColor = c),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPickerRow(
                    ctx,
                    'Ссылки',
                    linkColor,
                    (c) => setDialogState(() => linkColor = c),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPickerRow(
                    ctx,
                    'Выделение',
                    highlightColor,
                    (c) => setDialogState(() => highlightColor = c),
                  ),
                  const SizedBox(height: 16),
                  // Live preview card
                  _PresetPreviewCard(
                    background: bgColor,
                    text: fgColor,
                    link: linkColor,
                    highlight: highlightColor,
                  ),
                  const SizedBox(height: 12),
                  _ContrastWarning(background: bgColor, foreground: fgColor),
                  _ContrastWarning(background: bgColor, foreground: linkColor),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    final presets =
                        ref.read(colorPresetListProvider).value ?? const <ColorPreset>[];
                    var fallbackId = 'blue_light';
                    for (final p in presets) {
                      if (p.id != existing.id) {
                        fallbackId = p.id;
                        break;
                      }
                    }
                    await ref.read(colorPresetListProvider.notifier).remove(existing.id);
                    final currentSettings = ref.read(readerSettingsProvider);
                    if (currentSettings.activeColorPresetId == existing.id) {
                      notifier.updateActiveColorPresetId(fallbackId);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Удалить'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim().isEmpty
                      ? 'Мой'
                      : nameController.text.trim();
                  final preset = ColorPreset(
                    id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    backgroundColor: bgColor,
                    fontColor: fgColor,
                    linkColor: linkColor,
                    highlightColor: highlightColor,
                  );
                  if (existing != null) {
                    unawaited(ref.read(colorPresetListProvider.notifier).updatePreset(preset));
                  } else {
                    unawaited(ref.read(colorPresetListProvider.notifier).add(preset));
                  }
                  notifier.updateActiveColorPresetId(preset.id);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ).whenComplete(nameController.dispose),
    );
  }

  static Widget _buildColorPickerRow(
    BuildContext ctx,
    String label,
    Color color,
    ValueChanged<Color> onChanged,
  ) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showColorPicker(context: ctx, initialColor: color);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  static Widget _buildFontRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderFont.values.map((font) {
        final isSelected = settings.font == font;
        return ChoiceChip(
          label: Text(font.displayName),
          selected: isSelected,
          onSelected: (_) => notifier.updateFont(font),
        );
      }).toList(),
    );
  }

  static Widget _buildCustomFontTile(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final hasActive = settings.font == ReaderFont.custom;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (hasActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                ReaderFont.activeCustomFontFamily ?? 'Свой',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.font_download_outlined, size: 18),
            label: Text(hasActive ? 'Сменить' : 'Загрузить .ttf'),
            onPressed: () => _pickCustomFont(context, ref, settings, notifier),
          ),
        ],
      ),
    );
  }

  static Future<void> _pickCustomFont(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf', 'woff', 'woff2'],
      );
      if (file == null || file.path == null) return;
      final familyName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final ok = await CustomFontHelper.pickAndLoad(file.path!, familyName);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить шрифт')),
        );
        return;
      }
      notifier.updateFont(ReaderFont.custom);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  static Widget _buildFontSizeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: settings.fontSize > 10
              ? () => notifier.updateFontSize(settings.fontSize - 1)
              : null,
        ),
        Expanded(
          child: Slider(
            value: settings.fontSize,
            min: 10,
            max: 40,
            divisions: 30,
            label: '${settings.fontSize.round()}px',
            semanticFormatterCallback: (value) =>
                'Размер шрифта ${value.round()} пунктов, от 10 до 40 пунктов',
            onChanged: (v) => notifier.updateFontSize(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: settings.fontSize < 40
              ? () => notifier.updateFontSize(settings.fontSize + 1)
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${settings.fontSize.round()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  static Widget _buildNoteFontSizeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final effectiveNoteFontSize = settings.noteFontSize ?? settings.fontSize;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: effectiveNoteFontSize > 10
              ? () => notifier.updateNoteFontSize(effectiveNoteFontSize - 1)
              : null,
        ),
        Expanded(
          child: Slider(
            value: effectiveNoteFontSize,
            min: 10,
            max: 40,
            divisions: 30,
            label: '${effectiveNoteFontSize.round()}px',
            semanticFormatterCallback: (value) =>
                'Размер шрифта заметок ${value.round()} пунктов, от 10 до 40 пунктов',
            onChanged: (v) => notifier.updateNoteFontSize(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: effectiveNoteFontSize < 40
              ? () => notifier.updateNoteFontSize(effectiveNoteFontSize + 1)
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            settings.noteFontSize != null ? '${effectiveNoteFontSize.round()}' : 'Авто',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.restart_alt, size: 18),
          tooltip: 'Сбросить к размеру основного шрифта',
          onPressed: settings.noteFontSize != null ? () => notifier.updateNoteFontSize(null) : null,
        ),
      ],
    );
  }

  static Widget _buildFontWeightRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        const Icon(Icons.straighten, size: 20),
        Expanded(
          child: Slider(
            value: settings.fontWeightDelta,
            min: -1,
            divisions: 4,
            label: settings.fontWeightDelta == 0
                ? 'Норма'
                : settings.fontWeightDelta > 0
                ? 'Жирнее'
                : 'Тоньше',
            onChanged: (v) => notifier.updateFontWeightDelta(v),
          ),
        ),
      ],
    );
  }

  static Widget _buildLineHeightRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const values = [1.3, 1.4, 1.55, 1.7, 1.9];
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = (settings.lineHeight - v).abs() < 0.01;
        return ChoiceChip(
          label: Text(v.toStringAsFixed(2)),
          selected: isSelected,
          onSelected: (_) => notifier.updateLineHeight(v),
        );
      }).toList(),
    );
  }

  Widget _buildTextAlignRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const aligns = ReaderTextAlign.values;
    const labels = {
      ReaderTextAlign.left: 'Слева',
      ReaderTextAlign.justify: 'По ширине',
      ReaderTextAlign.center: 'Центр',
      ReaderTextAlign.right: 'Справа',
      ReaderTextAlign.asInBook: 'Как в книге',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: aligns.map((align) {
        return ChoiceChip(
          label: Text(labels[align] ?? align.name),
          selected: settings.textAlign == align,
          onSelected: (_) => notifier.updateTextAlign(align),
        );
      }).toList(),
    );
  }

  Widget _buildMarginRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final pct = settings.marginAsPercent;
    const pxValues = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
    const pctValues = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0];
    final values = pct ? pctValues : pxValues;
    final unit = pct ? '%' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!settings.separateMargins)
          Wrap(
            spacing: 8,
            children: values.map((v) {
              final isSelected = (settings.margin - v).abs() < 0.5;
              return ChoiceChip(
                label: Text('${v.round()}$unit'),
                selected: isSelected,
                onSelected: (_) => notifier.updateMargin(v),
              );
            }).toList(),
          )
        else
          _buildSeparateMargins(settings, notifier),
        const SizedBox(height: 4),
        Row(
          children: [
            Switch.adaptive(
              value: settings.separateMargins,
              onChanged: notifier.updateSeparateMargins,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Раздельные отступы',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('px')),
                ButtonSegment(value: true, label: Text('%')),
              ],
              selected: {pct},
              onSelectionChanged: (s) => notifier.updateMarginAsPercent(s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity(horizontal: -3, vertical: -3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeparateMargins(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    Widget marginSlider(String label, double value, ValueChanged<double> onChanged) {
      return _buildSliderRow(label, value / 48.0, 0.0, 1.0, (v) => onChanged(v * 48.0));
    }

    return Column(
      children: [
        marginSlider('Сверху', settings.marginTop, notifier.updateMarginTop),
        marginSlider('Снизу', settings.marginBottom, notifier.updateMarginBottom),
        marginSlider('Слева', settings.marginLeft, notifier.updateMarginLeft),
        marginSlider('Справа', settings.marginRight, notifier.updateMarginRight),
      ],
    );
  }

  static Widget _buildAutoThemeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AutoThemeMode.values.map((mode) {
            final isSelected = settings.autoThemeMode == mode;
            return ChoiceChip(
              label: Text(mode.displayName),
              selected: isSelected,
              onSelected: (_) => notifier.updateAutoThemeMode(mode),
            );
          }).toList(),
        ),
        if (settings.autoThemeMode == AutoThemeMode.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('День с: ', style: TextStyle(fontSize: 13)),
              DropdownButton<int>(
                value: settings.customDayHour,
                isDense: true,
                items: List.generate(
                  24,
                  (i) => DropdownMenuItem(value: i, child: Text('$i:00')),
                ),
                onChanged: (v) {
                  if (v != null) notifier.updateCustomDayHour(v);
                },
              ),
              const SizedBox(width: 16),
              const Text('Ночь с: ', style: TextStyle(fontSize: 13)),
              DropdownButton<int>(
                value: settings.customNightHour,
                isDense: true,
                items: List.generate(
                  24,
                  (i) => DropdownMenuItem(value: i, child: Text('$i:00')),
                ),
                onChanged: (v) {
                  if (v != null) notifier.updateCustomNightHour(v);
                },
              ),
            ],
          ),
        ],
        if (settings.autoThemeMode != AutoThemeMode.off) ...[
          const SizedBox(height: 12),
          const Text('Ночная тема:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                  ReaderTheme.dark,
                  ReaderTheme.oled,
                  ReaderTheme.bedtime,
                ].map((theme) {
                  final isSelected = settings.nightTheme == theme;
                  return ChoiceChip(
                    label: Text(theme.displayName),
                    selected: isSelected,
                    onSelected: (_) => notifier.updateNightTheme(theme),
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  // ponytail: one generic builder replaces 14 copy-paste enum rows
  static Widget _enumChoiceChips<T extends Enum>({
    required T current,
    required Map<T, String> labels,
    required ValueChanged<T> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              selected: current == e.key,
              onSelected: (_) => onChanged(e.key),
            ),
          )
          .toList(),
    );
  }

  static Widget _buildBrightnessRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        const Icon(Icons.brightness_low, size: 20),
        Expanded(
          child: Slider(
            value: settings.brightness,
            min: 0.2,
            divisions: 8,
            label: '${(settings.brightness * 100).round()}%',
            onChanged: (v) => notifier.updateBrightness(v),
          ),
        ),
        const Icon(Icons.brightness_high, size: 20),
      ],
    );
  }

  static Widget _buildWarmthRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        const Icon(Icons.wb_sunny_outlined, size: 20),
        Expanded(
          child: Slider(
            value: settings.warmth,
            divisions: 10,
            label: '${(settings.warmth * 100).round()}%',
            onChanged: (v) => notifier.updateWarmth(v),
          ),
        ),
        const Icon(Icons.wb_sunny, size: 20, color: Colors.orange),
      ],
    );
  }

  static Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 5,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ponytail: enum rows → inline _enumChoiceChips
  static Widget _buildImageAlignmentRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.imageAlignment,
    labels: const {
      ImageAlignment.start: 'По левому краю',
      ImageAlignment.center: 'По центру',
      ImageAlignment.end: 'По правому краю',
    },
    onChanged: (v) => notifier.updateImageAlignment(v),
  );

  static Widget _buildImageColorEffectRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.imageColorEffect,
    labels: const {
      ImageColorEffect.off: 'Нет',
      ImageColorEffect.grayscale: 'Ч/Б',
      ImageColorEffect.fontColor: 'Цвет шрифта',
      ImageColorEffect.backgroundColor: 'Цвет фона',
    },
    onChanged: (v) => notifier.updateImageColorEffect(v),
  );

  static Widget _buildToggleRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isEink = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isEink ? Colors.black : null),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: isEink ? const TextStyle(color: Colors.black) : null,
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: isEink ? Colors.black : null,
          activeTrackColor: isEink ? Colors.black26 : null,
          inactiveTrackColor: isEink ? Colors.grey.shade300 : null,
        ),
      ],
    );
  }

  static Widget _buildAutoHideRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const values = [0, 3, 5, 10, 15];
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = settings.autoHideDelay == v;
        return ChoiceChip(
          label: Text(v == 0 ? 'Никогда' : '$v'),
          selected: isSelected,
          onSelected: (_) => notifier.updateAutoHideDelay(v),
        );
      }).toList(),
    );
  }

  static Widget _buildProgressBarPositionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.progressBarPosition,
    labels: const {
      ProgressBarPosition.top: 'Сверху',
      ProgressBarPosition.bottom: 'Снизу',
      ProgressBarPosition.hidden: 'Скрыта',
    },
    onChanged: (v) => notifier.updateProgressBarPosition(v),
  );

  static Widget _buildBottomBarContentRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.bottomBarContent,
    labels: const {
      BottomBarContent.percent: 'Процент',
      BottomBarContent.page: 'Страница',
      BottomBarContent.chapter: 'Глава',
      BottomBarContent.time: 'Время',
      BottomBarContent.none: 'Скрыта',
    },
    onChanged: (v) => notifier.updateBottomBarContent(v),
  );

  static Widget _buildPageTurnAnimationRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.pageTurnAnimation,
    labels: const {
      PageTurnAnimation.none: 'Нет',
      PageTurnAnimation.slide: 'Слайд',
      PageTurnAnimation.fade: 'Затухание',
      PageTurnAnimation.curl: 'Свертывание',
      PageTurnAnimation.stack: 'Стопка',
    },
    onChanged: (v) => notifier.updatePageTurnAnimation(v),
  );

  static Widget _buildTextDirectionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.textDirection,
    labels: const {
      ReaderTextDirection.ltr: 'LTR',
      ReaderTextDirection.rtl: 'RTL',
      ReaderTextDirection.auto: 'Авто',
    },
    onChanged: (v) => notifier.updateTextDirection(v),
  );

  static Widget _buildReaderWidthRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        const Icon(Icons.drag_handle, size: 20),
        Expanded(
          child: Slider(
            value: settings.readerWidth,
            min: 600,
            max: 1000,
            divisions: 20,
            label: '${settings.readerWidth.round()}px',
            onChanged: (v) => notifier.updateReaderWidth(v),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${settings.readerWidth.round()}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  static Widget _buildDoubleTapActionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.doubleTapAction,
    labels: const {
      DoubleTapAction.toggleUI: 'Скрыть/показать UI',
      DoubleTapAction.addBookmark: 'Закладка',
      DoubleTapAction.searchInBook: 'Поиск',
      DoubleTapAction.disabled: 'Выкл',
    },
    onChanged: (v) => notifier.updateDoubleTapAction(v),
  );

  static Widget _buildLongPressActionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.longPressAction,
    labels: const {
      LongPressAction.selectText: 'Выделить текст',
      LongPressAction.addBookmark: 'Закладка',
      LongPressAction.openMenu: 'Меню',
      LongPressAction.disabled: 'Выкл',
    },
    onChanged: (v) => notifier.updateLongPressAction(v),
  );

  static Widget _buildCornerTapMap(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = <ReaderCorner, String>{
      ReaderCorner.topLeft: 'Верхний левый',
      ReaderCorner.topRight: 'Верхний правый',
      ReaderCorner.bottomLeft: 'Нижний левый',
      ReaderCorner.bottomRight: 'Нижний правый',
    };
    final actions = <ReaderCorner, CornerTapAction>{
      ReaderCorner.topLeft: settings.topLeftCornerTapAction,
      ReaderCorner.topRight: settings.topRightCornerTapAction,
      ReaderCorner.bottomLeft: settings.bottomLeftCornerTapAction,
      ReaderCorner.bottomRight: settings.bottomRightCornerTapAction,
    };
    final isDefault = actions.values.every((action) => action == CornerTapAction.inherit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Тапы по углам')),
            TextButton(
              onPressed: isDefault ? null : notifier.resetCornerTapActions,
              child: const Text('Сбросить'),
            ),
          ],
        ),
        const Text(
          'Угловой тап имеет приоритет над перелистыванием по краю. '
          'Долгое нажатие остаётся доступным для выделения текста.',
        ),
        const SizedBox(height: 8),
        for (final corner in ReaderCorner.values)
          DropdownButtonFormField<CornerTapAction>(
            key: ValueKey('corner-tap-${corner.name}'),
            initialValue: actions[corner],
            decoration: InputDecoration(labelText: labels[corner]),
            items: [
              for (final action in CornerTapAction.values)
                DropdownMenuItem(value: action, child: Text(action.displayName)),
            ],
            onChanged: (action) {
              if (action != null) notifier.updateCornerTapAction(corner, action);
            },
          ),
      ],
    );
  }

  static Widget _buildCornerLongPressMap(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = <ReaderCorner, String>{
      ReaderCorner.topLeft: 'Верхний левый',
      ReaderCorner.topRight: 'Верхний правый',
      ReaderCorner.bottomLeft: 'Нижний левый',
      ReaderCorner.bottomRight: 'Нижний правый',
    };
    final actions = <ReaderCorner, CornerLongPressAction>{
      ReaderCorner.topLeft: settings.topLeftCornerLongPressAction,
      ReaderCorner.topRight: settings.topRightCornerLongPressAction,
      ReaderCorner.bottomLeft: settings.bottomLeftCornerLongPressAction,
      ReaderCorner.bottomRight: settings.bottomRightCornerLongPressAction,
    };
    final isDefault = actions.values.every((action) => action == CornerLongPressAction.inherit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Долгое нажатие по углам')),
            TextButton(
              key: const ValueKey('reset-corner-long-press-actions'),
              onPressed: isDefault ? null : notifier.resetCornerLongPressActions,
              child: const Text('Сбросить'),
            ),
          ],
        ),
        const Text(
          'Настроенное действие срабатывает только в этом углу; '
          'в остальном тексте долгое нажатие сохраняет выделение.',
        ),
        const SizedBox(height: 8),
        for (final corner in ReaderCorner.values)
          DropdownButtonFormField<CornerLongPressAction>(
            key: ValueKey('corner-long-press-${corner.name}'),
            initialValue: actions[corner],
            decoration: InputDecoration(labelText: labels[corner]),
            items: [
              for (final action in CornerLongPressAction.values)
                DropdownMenuItem(value: action, child: Text(action.displayName)),
            ],
            onChanged: (action) {
              if (action != null) notifier.updateCornerLongPressAction(corner, action);
            },
          ),
      ],
    );
  }

  static Widget _buildHorizontalGestureRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.horizontalGesture,
    labels: const {
      HorizontalGesture.off: 'Выкл',
      HorizontalGesture.on: 'Вкл',
      HorizontalGesture.inverse: 'Инверсия',
    },
    onChanged: (v) => notifier.updateHorizontalGesture(v),
  );

  static Widget _buildHorizontalGestureScrollRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.horizontalGestureScroll,
    labels: const {
      HorizontalGestureScroll.half: '1/2 экрана',
      HorizontalGestureScroll.twoThirds: '2/3 экрана',
      HorizontalGestureScroll.threeQuarters: '3/4 экрана',
    },
    onChanged: (v) => notifier.updateHorizontalGestureScroll(v),
  );

  static Widget _buildOrientationLockRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.orientationLock,
    labels: const {
      OrientationLock.none: 'Система',
      OrientationLock.portrait: 'Книжная',
      OrientationLock.landscape: 'Альбомная',
    },
    onChanged: (v) => notifier.updateOrientationLock(v),
  );

  static Widget _buildParagraphIndentModeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) => _enumChoiceChips(
    current: settings.paragraphIndentMode,
    labels: const {
      ParagraphIndentMode.asInBook: 'Как в книге',
      ParagraphIndentMode.firstLine: 'Первая строка',
      ParagraphIndentMode.emptyLine: 'Пустая строка',
      ParagraphIndentMode.custom: 'Свой',
    },
    onChanged: (v) => notifier.updateParagraphIndentMode(v),
  );

  static const _encodingOptions = <String?>[
    null,
    'utf-8',
    'windows-1251',
    'koi8-r',
    'ibm866',
    'iso-8859-5',
    'utf-16le',
    'utf-16be',
  ];

  static const _encodingLabels = <String, String>{
    'utf-8': 'UTF-8',
    'windows-1251': 'Windows-1251',
    'koi8-r': 'KOI8-R',
    'ibm866': 'CP866',
    'iso-8859-5': 'ISO-8859-5',
    'utf-16le': 'UTF-16 LE',
    'utf-16be': 'UTF-16 BE',
  };

  static Widget _buildEncodingRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _encodingOptions.map((encoding) {
        final isSelected = settings.forcedEncoding == encoding;
        final label = encoding == null ? 'Авто' : (_encodingLabels[encoding] ?? encoding);
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => notifier.updateForcedEncoding(encoding),
        );
      }).toList(),
    );
  }

  static Widget _buildPerBookSection(
    BuildContext context,
    WidgetRef ref,
    String bookId,
    ReaderSettings settings,
  ) {
    return FutureBuilder<bool>(
      future: ref.read(perBookSettingsServiceProvider).hasPerBookSettings(bookId),
      builder: (context, snapshot) {
        final hasPerBook = snapshot.data ?? false;
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                hasPerBook ? Icons.bookmark : Icons.bookmark_add_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPerBook ? 'Индивидуальные настройки' : 'Сохранить оформление для этой книги',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final service = ref.read(perBookSettingsServiceProvider);
                  if (hasPerBook) {
                    await service.resetToGlobal(bookId);
                  } else {
                    await service.saveReadingAppearance(bookId, settings);
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(hasPerBook ? 'Сбросить' : 'Сохранить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerBookTypographySection(
    BuildContext context,
    WidgetRef ref,
    String bookId,
    ReaderSettings settings,
  ) {
    final typo = ref.watch(readerTypographyProvider(bookId));
    final notifier = ref.read(readerTypographyProvider(bookId).notifier);
    final theme = Theme.of(context);
    final hasOverrides = !typo.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Индивидуальная типографика',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasOverrides)
                TextButton(
                  onPressed: () => notifier.reset(),
                  child: const Text('Сбросить'),
                ),
            ],
          ),
          if (!hasOverrides)
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Сохранить текущую типографику'),
              onPressed: () => notifier.update(
                ReaderTypography(
                  fontSize: settings.fontSize,
                  lineHeight: settings.lineHeight,
                  marginHorizontal: settings.margin,
                  fontFamily: settings.font.name,
                ),
              ),
            )
          else ...[
            _buildPerBookSlider(
              'Шрифт',
              typo.fontSize ?? settings.fontSize,
              10,
              40,
              (v) => notifier.update(typo.copyWith(fontSize: v)),
              onClear: () => notifier.update(typo.copyWith(clearFontSize: true)),
              isOverridden: typo.fontSize != null,
            ),
            _buildPerBookSlider(
              'Межстрочный',
              typo.lineHeight ?? settings.lineHeight,
              1.0,
              3.0,
              (v) => notifier.update(typo.copyWith(lineHeight: v)),
              onClear: () => notifier.update(typo.copyWith(clearLineHeight: true)),
              isOverridden: typo.lineHeight != null,
            ),
            _buildPerBookSlider(
              'Отступы',
              typo.marginHorizontal ?? settings.margin,
              0,
              60,
              (v) => notifier.update(typo.copyWith(marginHorizontal: v)),
              onClear: () => notifier.update(typo.copyWith(clearMarginHorizontal: true)),
              isOverridden: typo.marginHorizontal != null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerBookSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required VoidCallback onClear,
    required bool isOverridden,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label ${value.round()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isOverridden ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        if (isOverridden)
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ContrastWarning extends StatelessWidget {
  const _ContrastWarning({required this.background, required this.foreground});
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final preview = ReaderColorPreview.fromColors(
      background: background,
      text: foreground,
      link: foreground,
    );
    final ratio = preview.textContrast;
    final passes = ratio >= 4.5;
    if (passes) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Контраст ${ratio.toStringAsFixed(1)}:1 — ниже нормы WCAG AA (4.5:1)',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetPreviewCard extends StatelessWidget {
  const _PresetPreviewCard({
    required this.background,
    required this.text,
    required this.link,
    required this.highlight,
  });

  final Color background;
  final Color text;
  final Color link;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final preview = ReaderColorPreview.fromColors(
      background: background,
      text: text,
      link: link,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Обычный текст',
            style: TextStyle(color: text, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Текст с ',
                  style: TextStyle(color: text, fontSize: 14),
                ),
                TextSpan(
                  text: 'ссылкой',
                  style: TextStyle(
                    color: link,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: highlight,
            child: Text('Выделенный текст', style: TextStyle(color: text, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          Text(
            'Т ${preview.textContrast.toStringAsFixed(1)} · С ${preview.linkContrast.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 10,
              color: text.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Color?> showColorPicker({
  required BuildContext context,
  required Color initialColor,
}) {
  final colors = [
    Colors.white,
    Colors.black,
    Colors.grey.shade800,
    Colors.grey.shade500,
    Colors.red.shade700,
    Colors.pink.shade300,
    Colors.purple.shade300,
    Colors.deepPurple.shade300,
    Colors.blue.shade700,
    Colors.blue.shade300,
    Colors.cyan.shade300,
    Colors.teal.shade300,
    Colors.green.shade700,
    Colors.lightGreen.shade300,
    Colors.amber.shade700,
    Colors.orange.shade700,
    const Color(0xFFF5F0E6),
    const Color(0xFFF4ECD8),
    const Color(0xFF111318),
    const Color(0xFF1A1612),
    const Color(0xFFFAF8FF),
    const Color(0xFF2C2C2C),
  ];
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Выберите цвет'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors.map((c) {
          final isSelected = c.toARGB32() == initialColor.toARGB32();
          return GestureDetector(
            onTap: () => Navigator.of(ctx).pop(c),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}
