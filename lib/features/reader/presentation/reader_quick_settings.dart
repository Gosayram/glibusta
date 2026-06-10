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
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Прокрутка'),
            selected: settings.mode == ReaderMode.continuous,
            onSelected: (_) => notifier.updateMode(ReaderMode.continuous),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: const Text('По страницам'),
            selected: settings.mode == ReaderMode.paginated,
            onSelected: (_) => notifier.updateMode(ReaderMode.paginated),
          ),
        ),
      ],
    );
  }
}
