import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reader_colors.dart';
import '../domain/reader.dart';
import 'reader_providers.dart';

class ReaderQuickSettingsSheet extends ConsumerWidget {
  const ReaderQuickSettingsSheet({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),

              const Text('Тема', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildThemeRow(context, settings, notifier),
              const SizedBox(height: 20),

              const Text('Шрифт', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildFontRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Размер шрифта', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildFontSizeRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Межстрочный', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildLineHeightRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Отступы', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildMarginRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Авто-тема', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildAutoThemeRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Режим', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildModeRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Яркость', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildBrightnessRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Тёплый фильтр', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildWarmthRow(settings, notifier),
              const SizedBox(height: 20),

              _buildToggleRow(
                'Не выключать экран',
                Icons.screen_lock_portrait,
                settings.keepScreenAwake,
                (v) => notifier.updateKeepScreenAwake(v),
              ),
              const SizedBox(height: 12),

              _buildToggleRow(
                'Переносы',
                Icons.format_textdirection_l_to_r,
                settings.hyphenation,
                (v) => notifier.updateHyphenation(v),
              ),
              const SizedBox(height: 20),

              const Text('Скрытие UI (сек)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildAutoHideRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Позиция прогресса', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildProgressBarPositionRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Содержимое нижней панели', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildBottomBarContentRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Зоны касания', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildTapZoneRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Анимация страниц', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildPageTurnAnimationRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Направление текста', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildTextDirectionRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Ширина читателя', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildReaderWidthRow(settings, notifier),
              const SizedBox(height: 20),

              _buildToggleRow(
                'Вертикальный свайп для яркости',
                Icons.swipe_up,
                settings.verticalSwipeBrightness,
                (v) => notifier.updateVerticalSwipeBrightness(v),
              ),
              const SizedBox(height: 20),

              const Text('Двойной тап', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildDoubleTapActionRow(settings, notifier),
              const SizedBox(height: 20),

              const Text('Долгое нажатие', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildLongPressActionRow(settings, notifier),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

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
                items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
                onChanged: (v) {
                  if (v != null) notifier.updateCustomDayHour(v);
                },
              ),
              const SizedBox(width: 16),
              const Text('Ночь с: ', style: TextStyle(fontSize: 13)),
              DropdownButton<int>(
                value: settings.customNightHour,
                isDense: true,
                items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
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
      DoubleTapAction.addBookmark: 'Добавить закладку',
      DoubleTapAction.toggleFullscreen: 'Полноэкранный режим',
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
      LongPressAction.addBookmark: 'Добавить закладку',
      LongPressAction.openMenu: 'Открыть меню',
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
}
