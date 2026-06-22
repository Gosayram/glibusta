import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/color_preset_service.dart';
import '../data/per_book_settings_service.dart';
import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'color_preset_provider.dart';
import 'reader_providers.dart';

class ReaderQuickSettingsSheet extends ConsumerStatefulWidget {
  const ReaderQuickSettingsSheet({super.key, this.onDismiss, this.bookId});

  final VoidCallback? onDismiss;
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPageIndicator(context),
            const SizedBox(height: 8),
            if (widget.bookId != null) _buildPerBookSection(context, ref, widget.bookId!),
            SizedBox(
              height: _estimatedPageHeight(context),
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPage1(context, settings, notifier),
                  _buildPage2(context, settings, notifier),
                  _buildPage3(context, settings, notifier),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  double _estimatedPageHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return screenH * 0.5;
  }

  Widget _buildPageIndicator(BuildContext context) {
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
              color: isActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _pageLabels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
    ReaderSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const _SectionTitle('Тема'),
        _buildThemeRow(context, settings, notifier),
        const SizedBox(height: 8),
        _buildColorPresetRow(context, ref, settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Шрифт'),
        _buildFontRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Размер шрифта'),
        _buildFontSizeRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Толщина шрифта'),
        _buildFontWeightRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Межстрочный'),
        _buildLineHeightRow(settings, notifier),
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
        const _SectionTitle('Отступ первой строки'),
        _buildSliderRow(
          'Шаг',
          settings.paragraphFirstLineIndent / 64.0,
          0.0,
          1.0,
          (v) => notifier.updateParagraphFirstLineIndent(v * 64.0),
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
    ReaderSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const _SectionTitle('Режим чтения'),
        _buildModeRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Текст и переносы'),
        _buildTextDirectionRow(settings, notifier),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Переносы слов',
          Icons.format_textdirection_l_to_r,
          settings.hyphenation,
          (v) => notifier.updateHyphenation(v),
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
        ),
      ],
    );
  }

  // ── Page 3: Жесты (Gestures & behavior) ──

  Widget _buildPage3(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const _SectionTitle('Горизонтальный жест'),
        _buildHorizontalGestureRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Чувствительность свайпа'),
        _buildHorizontalGestureScrollRow(settings, notifier),
        const SizedBox(height: 16),
        _buildToggleRow(
          'Вертикальный свайп для яркости',
          Icons.swipe_up,
          settings.verticalSwipeBrightness,
          (v) => notifier.updateVerticalSwipeBrightness(v),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Расширитель восприятия',
          Icons.view_sidebar_outlined,
          settings.perceptionExpander,
          (v) => notifier.updatePerceptionExpander(v),
        ),
        const SizedBox(height: 12),

        _buildToggleRow(
          'Горизонтальный лимитер',
          Icons.center_focus_strong,
          settings.horizontalLimiter,
          (v) => notifier.updateHorizontalLimiter(v),
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
          ),
        ],
        const SizedBox(height: 12),

        _buildToggleRow(
          'Bionic Reading',
          Icons.speed,
          settings.bionicReading,
          (v) => notifier.updateBionicReading(v),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Полоса прокрутки',
          Icons.view_sidebar_outlined,
          settings.scrollbarIndicator,
          (v) => notifier.updateScrollbarIndicator(v),
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          'Скрытие панелей при прокрутке',
          Icons.speed,
          settings.hideBarsOnFastScroll,
          (v) => notifier.updateHideBarsOnFastScroll(v),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Ориентация экрана'),
        _buildOrientationLockRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Зоны касания'),
        _buildTapZoneRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Двойной тап'),
        _buildDoubleTapActionRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Долгое нажатие'),
        _buildLongPressActionRow(settings, notifier),
        const SizedBox(height: 16),
        const _SectionTitle('Скрытие UI (сек)'),
        _buildAutoHideRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Позиция прогресса'),
        _buildProgressBarPositionRow(settings, notifier),
        const SizedBox(height: 12),
        const _SectionTitle('Нижняя панель'),
        _buildBottomBarContentRow(settings, notifier),
      ],
    );
  }

  // ── Shared builders ──

  static Widget _buildThemeRow(
    BuildContext context,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderTheme.values.map((theme) {
        final isSelected = settings.theme == theme;
        final colors = ReaderColors.forTheme(theme);
        return GestureDetector(
          onTap: () => notifier.updateTheme(theme),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.scaffold,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPresetRow(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
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
                return GestureDetector(
                  onTap: () => notifier.updateActiveColorPresetId(preset.id),
                  onLongPress: () => _showColorPresetEditor(
                    context,
                    ref,
                    preset,
                    notifier,
                  ),
                  child: Tooltip(
                    message: preset.name,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: preset.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
    final nameController = TextEditingController(text: existing?.name ?? '');

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(existing != null ? 'Редактировать' : 'Новый пресет'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text('Фон', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            final color = await showColorPicker(
                              context: ctx,
                              initialColor: bgColor,
                            );
                            if (color != null) setDialogState(() => bgColor = color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Текст', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            final color = await showColorPicker(
                              context: ctx,
                              initialColor: fgColor,
                            );
                            if (color != null) setDialogState(() => fgColor = color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: fgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Превью', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(color: fgColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    unawaited(ref.read(colorPresetListProvider.notifier).remove(existing.id));
                    final currentSettings = ref.read(readerSettingsProvider);
                    if (currentSettings.activeColorPresetId == existing.id) {
                      notifier.updateActiveColorPresetId('blue_light');
                    }
                    Navigator.of(ctx).pop();
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
      ),
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

  static Widget _buildFontSizeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 20),
          onPressed: settings.fontSize > 12
              ? () => notifier.updateFontSize(settings.fontSize - 1)
              : null,
        ),
        Expanded(
          child: Slider(
            value: settings.fontSize,
            min: 12,
            max: 32,
            divisions: 20,
            label: '${settings.fontSize.round()}px',
            onChanged: (v) => notifier.updateFontSize(v),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: settings.fontSize < 32
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

  static Widget _buildMarginRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const values = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final isSelected = (settings.margin - v).abs() < 0.5;
        return ChoiceChip(
          label: Text('${v.round()}'),
          selected: isSelected,
          onSelected: (_) => notifier.updateMargin(v),
        );
      }).toList(),
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
      ],
    );
  }

  static Widget _buildModeRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const modeLabels = {
      ReaderMode.auto: 'Авто',
      ReaderMode.continuous: 'Прокрутка',
      ReaderMode.paginated: 'Страницы',
      ReaderMode.twoPage: '2 колонки',
      ReaderMode.focus: 'Фокус',
      ReaderMode.fullscreen: 'Полный',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReaderMode.values.map((mode) {
        return ChoiceChip(
          label: Text(modeLabels[mode]!),
          selected: settings.mode == mode,
          onSelected: (_) => notifier.updateMode(mode),
        );
      }).toList(),
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

  static Widget _buildImageAlignmentRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      ImageAlignment.start: 'По левому краю',
      ImageAlignment.center: 'По центру',
      ImageAlignment.end: 'По правому краю',
    };
    return Wrap(
      spacing: 8,
      children: ImageAlignment.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.imageAlignment == v,
          onSelected: (_) => notifier.updateImageAlignment(v),
        );
      }).toList(),
    );
  }

  static Widget _buildImageColorEffectRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      ImageColorEffect.off: 'Нет',
      ImageColorEffect.grayscale: 'Ч/Б',
      ImageColorEffect.fontColor: 'Цвет шрифта',
      ImageColorEffect.backgroundColor: 'Цвет фона',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ImageColorEffect.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.imageColorEffect == v,
          onSelected: (_) => notifier.updateImageColorEffect(v),
        );
      }).toList(),
    );
  }

  static Widget _buildToggleRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Switch.adaptive(value: value, onChanged: onChanged),
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
  ) {
    const labels = {
      ProgressBarPosition.top: 'Сверху',
      ProgressBarPosition.bottom: 'Снизу',
      ProgressBarPosition.hidden: 'Скрыта',
    };
    return Wrap(
      spacing: 8,
      children: ProgressBarPosition.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.progressBarPosition == v,
          onSelected: (_) => notifier.updateProgressBarPosition(v),
        );
      }).toList(),
    );
  }

  static Widget _buildBottomBarContentRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      BottomBarContent.percent: 'Процент',
      BottomBarContent.page: 'Страница',
      BottomBarContent.chapter: 'Глава',
      BottomBarContent.time: 'Время',
      BottomBarContent.none: 'Скрыта',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BottomBarContent.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.bottomBarContent == v,
          onSelected: (_) => notifier.updateBottomBarContent(v),
        );
      }).toList(),
    );
  }

  static Widget _buildTapZoneRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      TapZoneLayout.third: '1/3',
      TapZoneLayout.quarter: '1/4',
      TapZoneLayout.edge: 'Край',
    };
    return Wrap(
      spacing: 8,
      children: TapZoneLayout.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.tapZoneLayout == v,
          onSelected: (_) => notifier.updateTapZoneLayout(v),
        );
      }).toList(),
    );
  }

  static Widget _buildPageTurnAnimationRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      PageTurnAnimation.none: 'Нет',
      PageTurnAnimation.slide: 'Слайд',
      PageTurnAnimation.fade: 'Затухание',
      PageTurnAnimation.curl: 'Свертывание',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PageTurnAnimation.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.pageTurnAnimation == v,
          onSelected: (_) => notifier.updatePageTurnAnimation(v),
        );
      }).toList(),
    );
  }

  static Widget _buildTextDirectionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      ReaderTextDirection.ltr: 'LTR',
      ReaderTextDirection.rtl: 'RTL',
      ReaderTextDirection.auto: 'Авто',
    };
    return Wrap(
      spacing: 8,
      children: ReaderTextDirection.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.textDirection == v,
          onSelected: (_) => notifier.updateTextDirection(v),
        );
      }).toList(),
    );
  }

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
  ) {
    const labels = {
      DoubleTapAction.toggleUI: 'Скрыть/показать UI',
      DoubleTapAction.addBookmark: 'Закладка',
      DoubleTapAction.toggleFullscreen: 'Полноэкранный',
      DoubleTapAction.translate: 'Перевести абзац',
      DoubleTapAction.disabled: 'Выкл',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DoubleTapAction.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.doubleTapAction == v,
          onSelected: (_) => notifier.updateDoubleTapAction(v),
        );
      }).toList(),
    );
  }

  static Widget _buildLongPressActionRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      LongPressAction.selectText: 'Выделить текст',
      LongPressAction.addBookmark: 'Закладка',
      LongPressAction.openMenu: 'Меню',
      LongPressAction.disabled: 'Выкл',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LongPressAction.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.longPressAction == v,
          onSelected: (_) => notifier.updateLongPressAction(v),
        );
      }).toList(),
    );
  }

  static Widget _buildHorizontalGestureRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      HorizontalGesture.off: 'Выкл',
      HorizontalGesture.on: 'Вкл',
      HorizontalGesture.inverse: 'Инверсия',
    };
    return Wrap(
      spacing: 8,
      children: HorizontalGesture.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.horizontalGesture == v,
          onSelected: (_) => notifier.updateHorizontalGesture(v),
        );
      }).toList(),
    );
  }

  static Widget _buildHorizontalGestureScrollRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      HorizontalGestureScroll.half: '1/2 экрана',
      HorizontalGestureScroll.twoThirds: '2/3 экрана',
      HorizontalGestureScroll.threeQuarters: '3/4 экрана',
    };
    return Wrap(
      spacing: 8,
      children: HorizontalGestureScroll.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.horizontalGestureScroll == v,
          onSelected: (_) => notifier.updateHorizontalGestureScroll(v),
        );
      }).toList(),
    );
  }

  static Widget _buildOrientationLockRow(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    const labels = {
      OrientationLock.none: 'Система',
      OrientationLock.portrait: 'Книжная',
      OrientationLock.landscape: 'Альбомная',
    };
    return Wrap(
      spacing: 8,
      children: OrientationLock.values.map((v) {
        return ChoiceChip(
          label: Text(labels[v]!),
          selected: settings.orientationLock == v,
          onSelected: (_) => notifier.updateOrientationLock(v),
        );
      }).toList(),
    );
  }

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
  ) {
    return FutureBuilder<bool>(
      future: ref.read(perBookSettingsServiceProvider).hasPerBookSettings(bookId),
      builder: (context, snapshot) {
        final hasPerBook = snapshot.data ?? false;
        if (!hasPerBook) return const SizedBox.shrink();
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
                Icons.bookmark,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Индивидуальные настройки',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(perBookSettingsServiceProvider).resetToGlobal(bookId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Сбросить'),
              ),
            ],
          ),
        );
      },
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
