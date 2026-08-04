import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorPreset {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color fontColor;
  final Color? linkColor;
  final Color? highlightColor;
  final int order;

  const ColorPreset({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.fontColor,
    this.linkColor,
    this.highlightColor,
    this.order = 0,
  });

  ColorPreset copyWith({
    String? name,
    Color? backgroundColor,
    Color? fontColor,
    Color? linkColor,
    bool clearLinkColor = false,
    Color? highlightColor,
    bool clearHighlightColor = false,
    int? order,
  }) {
    return ColorPreset(
      id: id,
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontColor: fontColor ?? this.fontColor,
      linkColor: clearLinkColor ? null : (linkColor ?? this.linkColor),
      highlightColor: clearHighlightColor ? null : (highlightColor ?? this.highlightColor),
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'backgroundColor': backgroundColor.toARGB32(),
    'fontColor': fontColor.toARGB32(),
    if (linkColor != null) 'linkColor': linkColor!.toARGB32(),
    if (highlightColor != null) 'highlightColor': highlightColor!.toARGB32(),
    'order': order,
  };

  factory ColorPreset.fromJson(Map<String, dynamic> json) => ColorPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    backgroundColor: Color(json['backgroundColor'] as int),
    fontColor: Color(json['fontColor'] as int),
    linkColor: json['linkColor'] != null ? Color(json['linkColor'] as int) : null,
    highlightColor: json['highlightColor'] != null ? Color(json['highlightColor'] as int) : null,
    order: json['order'] as int? ?? 0,
  );
}

class ColorPresetService {
  static const _key = 'reader_color_presets';

  static Future<List<ColorPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return _defaults;
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => ColorPreset.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } on Object catch (_) {
      return _defaults;
    }
  }

  static Future<void> save(List<ColorPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final indexed = <ColorPreset>[];
    for (var i = 0; i < presets.length; i++) {
      indexed.add(presets[i].copyWith(order: i));
    }
    final ok = await prefs.setString(
      _key,
      jsonEncode(indexed.map((p) => p.toJson()).toList()),
    );
    if (!ok) {
      // ponytail: preferences persist is best-effort, silently fail
      return;
    }
  }

  static final _defaults = [
    const ColorPreset(
      id: 'blue_light',
      name: 'Голубой',
      backgroundColor: Color(0xFFFAF8FF),
      fontColor: Color(0xFF44464F),
    ),
    const ColorPreset(
      id: 'warm_paper',
      name: 'Бумага',
      backgroundColor: Color(0xFFF5F0E6),
      fontColor: Color(0xFF3E3225),
    ),
    const ColorPreset(
      id: 'sepia',
      name: 'Сепия',
      backgroundColor: Color(0xFFF4ECD8),
      fontColor: Color(0xFF5B4636),
    ),
    const ColorPreset(
      id: 'dark',
      name: 'Тёмная',
      backgroundColor: Color(0xFF111318),
      fontColor: Color(0xFFE6E1E5),
    ),
    const ColorPreset(
      id: 'oled',
      name: 'OLED',
      backgroundColor: Color(0xFF000000),
      fontColor: Color(0xFFDADADA),
    ),
  ];
}
