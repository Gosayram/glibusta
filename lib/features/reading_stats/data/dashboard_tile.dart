import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_tile.freezed.dart';

enum DashboardTileType {
  totalTime,
  heatmap,
  weeklyChart,
  perBookBreakdown,
  streak,
  randomHighlight,
}

@freezed
abstract class DashboardTile with _$DashboardTile {
  const factory DashboardTile({
    required String id,
    required DashboardTileType type,
    @Default(0) int order,
  }) = _DashboardTile;
  const DashboardTile._();

  String get title {
    switch (type) {
      case DashboardTileType.totalTime:
        return 'Общее время чтения';
      case DashboardTileType.heatmap:
        return 'Календарь чтения';
      case DashboardTileType.weeklyChart:
        return 'Недельная статистика';
      case DashboardTileType.perBookBreakdown:
        return 'Время по книгам';
      case DashboardTileType.streak:
        return 'Серия чтения';
      case DashboardTileType.randomHighlight:
        return 'Случайный факт';
    }
  }

  IconData get icon {
    switch (type) {
      case DashboardTileType.totalTime:
        return Icons.timer_outlined;
      case DashboardTileType.heatmap:
        return Icons.calendar_month_outlined;
      case DashboardTileType.weeklyChart:
        return Icons.bar_chart_outlined;
      case DashboardTileType.perBookBreakdown:
        return Icons.library_books_outlined;
      case DashboardTileType.streak:
        return Icons.local_fire_department_outlined;
      case DashboardTileType.randomHighlight:
        return Icons.lightbulb_outlined;
    }
  }
}

class DashboardTileConfig {
  const DashboardTileConfig({required this.tiles});

  final List<DashboardTile> tiles;

  // ignore: prefer_constructors_over_static_methods
  static DashboardTileConfig defaultConfig() {
    return const DashboardTileConfig(
      tiles: [
        DashboardTile(id: 'streak', type: DashboardTileType.streak),
        DashboardTile(id: 'total', type: DashboardTileType.totalTime, order: 1),
        DashboardTile(id: 'heatmap', type: DashboardTileType.heatmap, order: 2),
        DashboardTile(id: 'weekly', type: DashboardTileType.weeklyChart, order: 3),
        DashboardTile(id: 'per_book', type: DashboardTileType.perBookBreakdown, order: 4),
        DashboardTile(id: 'highlight', type: DashboardTileType.randomHighlight, order: 5),
      ],
    );
  }

  DashboardTileConfig reorder(int oldIndex, int newIndex) {
    final reordered = List<DashboardTile>.from(tiles);
    if (oldIndex < newIndex) {
      reordered.removeAt(oldIndex);
      reordered.insert(newIndex - 1, reordered[oldIndex]);
    } else {
      reordered.removeAt(oldIndex);
      reordered.insert(newIndex, reordered[oldIndex]);
    }
    return DashboardTileConfig(
      tiles: reordered.asMap().entries.map((e) {
        return e.value.copyWith(order: e.key);
      }).toList(),
    );
  }
}
