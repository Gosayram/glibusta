import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_info_model.dart';
import 'reading_info_provider.dart';

class ReadingInfoSettingsScreen extends ConsumerWidget {
  const ReadingInfoSettingsScreen({super.key, this.bookId});

  final String? bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch<ReadingInfoModel>(readingInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Info Bar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => ref.read<ReadingInfoNotifier>(readingInfoProvider.notifier).reset(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Header'),
          _SlotPicker(
            label: 'Left',
            value: config.headerLeft,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(headerLeft: mode)),
          ),
          _SlotPicker(
            label: 'Center',
            value: config.headerCenter,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(headerCenter: mode)),
          ),
          _SlotPicker(
            label: 'Right',
            value: config.headerRight,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(headerRight: mode)),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Footer'),
          _SlotPicker(
            label: 'Left',
            value: config.footerLeft,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(footerLeft: mode)),
          ),
          _SlotPicker(
            label: 'Center',
            value: config.footerCenter,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(footerCenter: mode)),
          ),
          _SlotPicker(
            label: 'Right',
            value: config.footerRight,
            onChanged: (InfoSlotMode mode) => ref
                .read<ReadingInfoNotifier>(readingInfoProvider.notifier)
                .update((s) => s.copyWith(footerRight: mode)),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            title: const Text('Font Size'),
            subtitle: Slider(
              value: config.fontSize,
              min: 10,
              max: 16,
              divisions: 6,
              label: config.fontSize.toStringAsFixed(0),
              onChanged: (double value) =>
                  ref.read<ReadingInfoNotifier>(readingInfoProvider.notifier).updateFontSize(value),
            ),
          ),
          ListTile(
            title: const Text('Margin'),
            subtitle: Slider(
              value: config.margin,
              min: 4,
              max: 16,
              divisions: 6,
              label: config.margin.toStringAsFixed(0),
              onChanged: (double value) =>
                  ref.read<ReadingInfoNotifier>(readingInfoProvider.notifier).updateMargin(value),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Preview'),
          _PreviewWidget(config: config),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final InfoSlotMode value;
  final ValueChanged<InfoSlotMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<InfoSlotMode>(
        value: value,
        items: InfoSlotMode.values.map((InfoSlotMode mode) {
          return DropdownMenuItem<InfoSlotMode>(
            value: mode,
            child: Text(_modeLabel(mode)),
          );
        }).toList(),
        onChanged: (InfoSlotMode? mode) {
          if (mode != null) onChanged(mode);
        },
      ),
    );
  }

  String _modeLabel(InfoSlotMode mode) {
    switch (mode) {
      case InfoSlotMode.none:
        return 'None';
      case InfoSlotMode.chapterTitle:
        return 'Chapter Title';
      case InfoSlotMode.chapterProgress:
        return 'Chapter Progress';
      case InfoSlotMode.bookProgress:
        return 'Book Progress';
      case InfoSlotMode.battery:
        return 'Battery';
      case InfoSlotMode.time:
        return 'Time';
      case InfoSlotMode.batteryAndTime:
        return 'Battery + Time';
    }
  }
}

class _PreviewWidget extends StatelessWidget {
  const _PreviewWidget({required this.config});

  final ReadingInfoModel config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: config.fontSize,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: EdgeInsets.all(config.margin),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildPreviewSlot(config.headerLeft, textStyle)),
              Expanded(child: _buildPreviewSlot(config.headerCenter, textStyle)),
              Expanded(child: _buildPreviewSlot(config.headerRight, textStyle)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            alignment: Alignment.center,
            child: Text(
              'Book Content',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildPreviewSlot(config.footerLeft, textStyle)),
              Expanded(child: _buildPreviewSlot(config.footerCenter, textStyle)),
              Expanded(child: _buildPreviewSlot(config.footerRight, textStyle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSlot(InfoSlotMode mode, TextStyle style) {
    switch (mode) {
      case InfoSlotMode.none:
        return const SizedBox.shrink();
      case InfoSlotMode.chapterTitle:
        return Text('Chapter 1', style: style, textAlign: TextAlign.center);
      case InfoSlotMode.chapterProgress:
        return Text('42%', style: style, textAlign: TextAlign.center);
      case InfoSlotMode.bookProgress:
        return Text('5 / 12', style: style, textAlign: TextAlign.center);
      case InfoSlotMode.battery:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_full, size: style.fontSize, color: style.color),
            const SizedBox(width: 4),
            Text('85%', style: style),
          ],
        );
      case InfoSlotMode.time:
        return Text('14:30', style: style, textAlign: TextAlign.center);
      case InfoSlotMode.batteryAndTime:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_full, size: style.fontSize, color: style.color),
            const SizedBox(width: 4),
            Text('14:30', style: style),
          ],
        );
    }
  }
}
