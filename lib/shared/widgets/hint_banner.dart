import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HintKey {
  longPressBook,
  swipeToChapter,
  pullDownRefresh,
  doubleTapZoom,
  volumePageTurn,
  pinchToResize,
  dragToReorder,
  tagBook,
  exportStats,
}

extension HintKeyExtension on HintKey {
  String get storageKey => 'hint_dismissed_$name';

  String get title {
    switch (this) {
      case HintKey.longPressBook:
        return 'Долгое нажатие';
      case HintKey.swipeToChapter:
        return 'Свайп влево';
      case HintKey.pullDownRefresh:
        return 'Потяните вниз';
      case HintKey.doubleTapZoom:
        return 'Двойной тап';
      case HintKey.volumePageTurn:
        return 'Кнопки громкости';
      case HintKey.pinchToResize:
        return ' pinch-to-zoom';
      case HintKey.dragToReorder:
        return 'Перетаскивание';
      case HintKey.tagBook:
        return 'Тегирование';
      case HintKey.exportStats:
        return 'Экспорт статистики';
    }
  }

  String get message {
    switch (this) {
      case HintKey.longPressBook:
        return 'Нажмите и удерживайте обложку книги для доступа к дополнительным действиям';
      case HintKey.swipeToChapter:
        return 'Проведите влево или вправо для перехода между главами';
      case HintKey.pullDownRefresh:
        return 'Потяните вниз для обновления содержимого';
      case HintKey.doubleTapZoom:
        return 'Дважды нажмите для масштабирования изображения';
      case HintKey.volumePageTurn:
        return 'Используйте кнопки громкости для перелистывания страниц';
      case HintKey.pinchToResize:
        return 'Используйте два пальца для масштабирования';
      case HintKey.dragToReorder:
        return 'Перетаскивайте элементы для изменения порядка';
      case HintKey.tagBook:
        return 'Добавляйте теги для организации библиотеки';
      case HintKey.exportStats:
        return 'Экспортируйте статистику чтения в CSV или JSON';
    }
  }

  IconData get icon {
    switch (this) {
      case HintKey.longPressBook:
        return Icons.touch_app_outlined;
      case HintKey.swipeToChapter:
        return Icons.swipe_left_outlined;
      case HintKey.pullDownRefresh:
        return Icons.refresh_outlined;
      case HintKey.doubleTapZoom:
        return Icons.zoom_in_outlined;
      case HintKey.volumePageTurn:
        return Icons.volume_up_outlined;
      case HintKey.pinchToResize:
        return Icons.pinch_outlined;
      case HintKey.dragToReorder:
        return Icons.drag_indicator_outlined;
      case HintKey.tagBook:
        return Icons.label_outlined;
      case HintKey.exportStats:
        return Icons.file_download_outlined;
    }
  }
}

class HintService {
  HintService(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> isDismissed(HintKey key) async {
    return _prefs.getBool(key.storageKey) ?? false;
  }

  Future<void> dismiss(HintKey key) async {
    await _prefs.setBool(key.storageKey, true);
  }

  Future<void> resetAll() async {
    for (final key in HintKey.values) {
      await _prefs.remove(key.storageKey);
    }
  }
}

class HintBanner extends StatefulWidget {
  const HintBanner({
    required this.hintKey,
    required this.child,
    this.onDismiss,
    super.key,
  });

  final HintKey hintKey;
  final Widget child;
  final VoidCallback? onDismiss;

  @override
  State<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends State<HintBanner> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHintState());
  }

  Future<void> _loadHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(widget.hintKey.storageKey) ?? false;
    if (mounted && !dismissed) {
      setState(() => _showBanner = true);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.hintKey.storageKey, true);
    if (mounted) {
      setState(() => _showBanner = false);
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) return widget.child;

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  widget.hintKey.icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.hintKey.title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.hintKey.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
