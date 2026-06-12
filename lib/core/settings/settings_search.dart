import 'package:flutter/material.dart';

class SettingsItem {
  const SettingsItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.icon,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final String section;
  final IconData icon;
  final List<String> keywords;
}

class SettingsSearchService {
  static List<SettingsItem> get allItems => [
    const SettingsItem(
      id: 'theme',
      title: 'Тёмная тема',
      subtitle: 'Использовать тёмную тему',
      section: 'Отображение',
      icon: Icons.dark_mode,
      keywords: ['тема', 'dark', 'colors', 'цвет'],
    ),
    const SettingsItem(
      id: 'content_safety',
      title: 'Фильтр контента',
      subtitle: 'Настройка безопасности',
      section: 'Отображение',
      icon: Icons.shield_outlined,
      keywords: ['фильтр', 'безопасность', '18+', 'adult'],
    ),
    const SettingsItem(
      id: 'concurrent_downloads',
      title: 'Одновременные загрузки',
      subtitle: 'Максимум загрузок параллельно',
      section: 'Загрузки',
      icon: Icons.download,
      keywords: ['загрузки', 'download', 'параллельно'],
    ),
    const SettingsItem(
      id: 'base_url',
      title: 'Базовый URL',
      subtitle: 'Адрес сервера Flibusta',
      section: 'Источник',
      icon: Icons.link,
      keywords: ['url', 'адрес', 'сервер', 'mirror', 'зеркало'],
    ),
    const SettingsItem(
      id: 'shortcuts',
      title: 'Горячие клавиши',
      subtitle: 'Список клавиш',
      section: 'Управление',
      icon: Icons.keyboard,
      keywords: ['клавиши', 'hotkey', 'keyboard', 'управление'],
    ),
    const SettingsItem(
      id: 'diagnostics',
      title: 'Диагностика',
      subtitle: 'Состояние приложения',
      section: 'О приложении',
      icon: Icons.bug_report,
      keywords: ['диагностика', 'debug', 'ошибки', 'логи'],
    ),
    const SettingsItem(
      id: 'language',
      title: 'Язык',
      subtitle: 'Язык интерфейса',
      section: 'Отображение',
      icon: Icons.language,
      keywords: ['язык', 'language', 'locale', 'интерфейс'],
    ),
    const SettingsItem(
      id: 'reader_font_size',
      title: 'Размер шрифта',
      subtitle: 'Настройка размера текста',
      section: 'Читалка',
      icon: Icons.text_fields,
      keywords: ['шрифт', 'font', 'размер', 'текст', 'size'],
    ),
    const SettingsItem(
      id: 'reader_theme',
      title: 'Тема читалки',
      subtitle: 'Цветовая схема для чтения',
      section: 'Читалка',
      icon: Icons.palette,
      keywords: ['читалка', 'reader', 'тема', 'sepia', 'ночная'],
    ),
    const SettingsItem(
      id: 'cache_clear',
      title: 'Очистить кэш',
      subtitle: 'Удалить временные файлы',
      section: 'Хранилище',
      icon: Icons.delete_sweep,
      keywords: ['кэш', 'cache', 'очистить', 'временные'],
    ),
  ];

  static List<SettingsItem> search(String query) {
    if (query.isEmpty) return allItems;
    final lower = query.toLowerCase();
    return allItems.where((item) {
      return item.title.toLowerCase().contains(lower) ||
          item.subtitle.toLowerCase().contains(lower) ||
          item.section.toLowerCase().contains(lower) ||
          item.keywords.any((k) => k.toLowerCase().contains(lower));
    }).toList();
  }

  static Map<String, List<SettingsItem>> groupBySection(List<SettingsItem> items) {
    final grouped = <String, List<SettingsItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }
    return grouped;
  }
}
