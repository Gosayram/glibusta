import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_providers.dart';
import '../../features/reader/data/reading_info_model.dart';
import '../../features/reader/presentation/reader_controller.dart';
import 'minute_clock.dart';

class ReadingInfoBar extends ConsumerWidget {
  const ReadingInfoBar({
    super.key,
    required this.config,
    required this.isHeader,
    required this.controller,
  });

  final ReadingInfoModel config;
  final bool isHeader;
  final ReaderController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_allSlotsNone()) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: config.fontSize,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: config.margin,
        vertical: config.margin / 2,
      ),
      child: Row(
        children: [
          Expanded(child: _buildSlot(isHeader ? config.headerLeft : config.footerLeft, textStyle)),
          Expanded(
            child: _buildSlot(isHeader ? config.headerCenter : config.footerCenter, textStyle),
          ),
          Expanded(
            child: _buildSlot(isHeader ? config.headerRight : config.footerRight, textStyle),
          ),
        ],
      ),
    );
  }

  bool _allSlotsNone() {
    if (isHeader) {
      return config.headerLeft == InfoSlotMode.none &&
          config.headerCenter == InfoSlotMode.none &&
          config.headerRight == InfoSlotMode.none;
    }
    return config.footerLeft == InfoSlotMode.none &&
        config.footerCenter == InfoSlotMode.none &&
        config.footerRight == InfoSlotMode.none;
  }

  Widget _buildSlot(InfoSlotMode mode, TextStyle style) {
    switch (mode) {
      case InfoSlotMode.none:
        return const SizedBox.shrink();
      case InfoSlotMode.chapterTitle:
        return _ChapterTitleWidget(controller: controller, style: style);
      case InfoSlotMode.chapterProgress:
        return _ChapterProgressWidget(controller: controller, style: style);
      case InfoSlotMode.bookProgress:
        return _BookProgressWidget(controller: controller, style: style);
      case InfoSlotMode.battery:
        return _BatteryWidget(style: style);
      case InfoSlotMode.time:
        return MinuteClock(style: style);
      case InfoSlotMode.batteryAndTime:
        return _BatteryAndTimeWidget(style: style);
    }
  }
}

class _ChapterTitleWidget extends StatelessWidget {
  const _ChapterTitleWidget({required this.controller, required this.style});

  final ReaderController controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final chapterTitle = state.chapterTitle(state.currentPosition.chapterIndex);
    if (chapterTitle.isEmpty) return const SizedBox.shrink();
    return Text(
      chapterTitle,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

class _ChapterProgressWidget extends StatelessWidget {
  const _ChapterProgressWidget({required this.controller, required this.style});

  final ReaderController controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final percent = (state.currentPosition.progressPercent * 100).toInt();
    return Text(
      '$percent%',
      style: style,
      textAlign: TextAlign.center,
    );
  }
}

class _BookProgressWidget extends StatelessWidget {
  const _BookProgressWidget({required this.controller, required this.style});

  final ReaderController controller;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final current = state.currentPosition.chapterIndex + 1;
    final total = state.chapterCount;
    return Text(
      '$current / $total',
      style: style,
      textAlign: TextAlign.center,
    );
  }
}

class _BatteryWidget extends ConsumerWidget {
  const _BatteryWidget({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batteryAsync = ref.watch(batteryLevelProvider);
    return batteryAsync.when(
      data: (level) {
        if (level < 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBatteryIcon(level),
              size: style.fontSize,
              color: style.color,
            ),
            const SizedBox(width: 4),
            Text(
              '$level%',
              style: style,
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level <= 0) return Icons.battery_unknown;
    if (level <= 10) return Icons.battery_1_bar;
    if (level <= 30) return Icons.battery_2_bar;
    if (level <= 50) return Icons.battery_3_bar;
    if (level <= 70) return Icons.battery_4_bar;
    if (level <= 90) return Icons.battery_5_bar;
    return Icons.battery_full;
  }
}

class _BatteryAndTimeWidget extends ConsumerWidget {
  const _BatteryAndTimeWidget({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BatteryWidget(style: style),
        const SizedBox(width: 8),
        MinuteClock(style: style),
      ],
    );
  }
}
