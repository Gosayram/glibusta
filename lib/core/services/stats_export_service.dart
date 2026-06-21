import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../telemetry/reader_telemetry.dart';

class StatsExportService {
  StatsExportService(this._db, this._telemetry);

  final AppDatabase _db;
  final ReaderTelemetry _telemetry;

  Future<String> exportToJson() async {
    final sessions = await _db.select(_db.readingSessions).get();
    final stats = await _telemetry.getAllStats();
    final totalMinutes = await _telemetry.getTotalReadingMinutes();

    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'totalReadingMinutes': totalMinutes,
      'bookStats': stats.map(
        (id, s) => MapEntry(id, {
          'bookId': s.bookId,
          'totalMinutes': s.totalTime.inMinutes,
          'sessionsCount': s.sessionsCount,
          'avgSessionMinutes': s.avgSessionMinutes.toStringAsFixed(1),
          'favoriteMode': s.favoriteMode,
          'lastRead': s.lastRead.toIso8601String(),
        }),
      ),
      'sessions': sessions
          .map(
            (s) => {
              'bookId': s.bookId,
              'startedAt': s.startedAt.toIso8601String(),
              'endedAt': s.endedAt?.toIso8601String(),
              'chaptersRead': s.chaptersRead,
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> exportToCsv() async {
    final stats = await _telemetry.getAllStats();
    final buffer = StringBuffer();
    buffer.writeln('Book ID,Total Minutes,Sessions,Avg Minutes,Mode,Last Read');
    for (final s in stats.values) {
      buffer.writeln(
        '"${s.bookId}",${s.totalTime.inMinutes},${s.sessionsCount},'
        '${s.avgSessionMinutes.toStringAsFixed(1)},${s.favoriteMode},'
        '${s.lastRead.toIso8601String()}',
      );
    }
    return buffer.toString();
  }

  Future<File> saveToFile(String content, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/glibusta/$filename');
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<void> shareJson() async {
    final json = await exportToJson();
    final file = await saveToFile(json, 'reading_stats.json');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Статистика чтения'),
    );
  }

  Future<void> shareCsv() async {
    final csv = await exportToCsv();
    final file = await saveToFile(csv, 'reading_stats.csv');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Статистика чтения'),
    );
  }
}

final statsExportServiceProvider = Provider<StatsExportService>((ref) {
  final db = ref.watch(databaseProvider);
  final telemetry = ref.watch(readerTelemetryProvider);
  return StatsExportService(db, telemetry);
});
