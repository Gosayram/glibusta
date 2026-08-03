import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/presentation/toc_hierarchy.dart';

// Replicate the filter logic from table_of_contents_sheet.dart
List<TocEntry> filterEntries(List<TocEntry> entries, String query) {
  if (query.isEmpty) return entries;
  final q = query.toLowerCase();
  return entries.where((e) => !e.isGroup && e.title.toLowerCase().contains(q)).toList();
}

void main() {
  final entries = <TocEntry>[
    const TocEntry(
      index: 0,
      title: 'Глава первая',
      depth: 0,
      isGroup: false,
      groupId: -1,
    ),
    const TocEntry(
      index: 1,
      title: 'Глава вторая',
      depth: 0,
      isGroup: false,
      groupId: -1,
    ),
    const TocEntry(
      index: 2,
      title: 'Приложение',
      depth: 0,
      isGroup: false,
      groupId: -1,
    ),
    const TocEntry(
      index: -1,
      title: 'Часть I',
      depth: 0,
      isGroup: true,
      groupId: 0,
    ),
  ];

  group('TOC search filter', () {
    test('empty query returns all entries', () {
      expect(filterEntries(entries, '').length, entries.length);
    });

    test('case-insensitive match', () {
      final result = filterEntries(entries, 'ГЛАВА');
      expect(result.length, 2);
      expect(result.every((e) => e.title.contains('Глава')), isTrue);
    });

    test('partial match works', () {
      final result = filterEntries(entries, 'прил');
      expect(result.length, 1);
      expect(result.first.title, 'Приложение');
    });

    test('groups are excluded from search results', () {
      final result = filterEntries(entries, 'Часть');
      expect(result.isEmpty, isTrue);
    });

    test('no match returns empty list', () {
      final result = filterEntries(entries, 'несуществующая');
      expect(result.isEmpty, isTrue);
    });
  });
}
