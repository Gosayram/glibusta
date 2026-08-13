import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/telemetry/reader_telemetry.dart' as telemetry;

final bookStatsListProvider = FutureProvider.autoDispose<Map<String, telemetry.BookStats>>((
  ref,
) async {
  final telemetryRepo = ref.watch(telemetry.readerTelemetryProvider);
  return telemetryRepo.getAllStats();
});

final favoriteGenresProvider = FutureProvider.autoDispose<List<MapEntry<String, int>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final topBooks = await db.readingTimeDao.getTopBooksByReadingTime(limit: 50);
  if (topBooks.isEmpty) return [];
  final bookIds = topBooks.map((r) => r.bookId).toList();
  final books = await db.bookDao.getBooksByIds(bookIds);
  final allGenres = await db.genreDao.getAllGenres();
  final genreMap = {for (final g in allGenres) g.id: g.name};
  final counts = <String, int>{};
  for (final book in books) {
    for (final gid in book.genreIds) {
      final name = genreMap[gid] ?? gid;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).toList();
});

final readingHoursProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final db = ref.watch(databaseProvider);
  final hourly = await db.readingTimeDao.getReadingHours(30);
  final result = List<int>.filled(24, 0);
  for (final entry in hourly.entries) {
    if (entry.key >= 0 && entry.key < 24) {
      result[entry.key] = entry.value;
    }
  }
  return result;
});

class _SessionStartNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void startSession() => state = DateTime.now();
  void endSession() => state = null;
}

final currentSessionStartProvider = NotifierProvider<_SessionStartNotifier, DateTime?>(
  _SessionStartNotifier.new,
);

final sessionTimerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream<DateTime>.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
