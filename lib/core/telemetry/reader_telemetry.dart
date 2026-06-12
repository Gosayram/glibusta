import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

class ReadingSession {
  const ReadingSession({
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    this.pagesRead = 0,
    this.chaptersRead = 0,
    this.mode = 'paginated',
  });

  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int pagesRead;
  final int chaptersRead;
  final String mode;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
}

class BookStats {
  const BookStats({
    required this.bookId,
    required this.totalTime,
    required this.sessionsCount,
    required this.avgSessionMinutes,
    required this.favoriteMode,
    required this.lastRead,
    this.openErrors = 0,
    this.fileSizeBytes = 0,
  });

  final String bookId;
  final Duration totalTime;
  final int sessionsCount;
  final double avgSessionMinutes;
  final String favoriteMode;
  final DateTime lastRead;
  final int openErrors;
  final int fileSizeBytes;
}

class ReaderTelemetry {
  ReaderTelemetry(this._prefs, this._logger);
  final SharedPreferences _prefs;
  final AppLogger _logger;

  static const _sessionsKey = 'reading_sessions';
  static const _errorsKey = 'reader_errors';

  ReadingSession? _currentSession;

  void startSession(String bookId, {String mode = 'paginated'}) {
    _currentSession = ReadingSession(
      bookId: bookId,
      startedAt: DateTime.now(),
      mode: mode,
    );
    _logger.info('Reading session started: $bookId', name: 'Telemetry');
  }

  void endSession({int pagesRead = 0, int chaptersRead = 0}) {
    if (_currentSession == null) return;

    final session = ReadingSession(
      bookId: _currentSession!.bookId,
      startedAt: _currentSession!.startedAt,
      endedAt: DateTime.now(),
      pagesRead: pagesRead,
      chaptersRead: chaptersRead,
      mode: _currentSession!.mode,
    );

    _saveSession(session);
    _logger.info(
      'Reading session ended: ${session.bookId} (${session.duration.inMinutes} min)',
      name: 'Telemetry',
    );
    _currentSession = null;
  }

  void recordError(String bookId, String error) {
    final errors = _prefs.getStringList(_errorsKey) ?? [];
    errors.add('$bookId|$error|${DateTime.now().toIso8601String()}');
    if (errors.length > 100) {
      errors.removeRange(0, errors.length - 100);
    }
    unawaited(_prefs.setStringList(_errorsKey, errors));
  }

  void recordOpen(String bookId) {
    _logger.info('Book opened: $bookId', name: 'Telemetry');
  }

  Future<List<ReadingSession>> getSessions({String? bookId, int limit = 50}) async {
    final raw = _prefs.getStringList(_sessionsKey) ?? [];
    final sessions = raw
        .map((s) => _parseSession(s))
        .where((s) => s != null)
        .cast<ReadingSession>()
        .toList();

    final filtered = bookId != null ? sessions.where((s) => s.bookId == bookId).toList() : sessions;

    filtered.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return filtered.take(limit).toList();
  }

  Future<Map<String, BookStats>> getAllStats() async {
    final sessions = await getSessions(limit: 1000);
    final stats = <String, BookStats>{};

    for (final session in sessions) {
      final existing = stats[session.bookId];
      if (existing == null) {
        stats[session.bookId] = BookStats(
          bookId: session.bookId,
          totalTime: session.duration,
          sessionsCount: 1,
          avgSessionMinutes: session.duration.inMinutes.toDouble(),
          favoriteMode: session.mode,
          lastRead: session.startedAt,
        );
      } else {
        final newTotal = existing.totalTime + session.duration;
        final newCount = existing.sessionsCount + 1;
        stats[session.bookId] = BookStats(
          bookId: session.bookId,
          totalTime: newTotal,
          sessionsCount: newCount,
          avgSessionMinutes: newTotal.inMinutes / newCount,
          favoriteMode: existing.favoriteMode,
          lastRead: session.startedAt.isAfter(existing.lastRead)
              ? session.startedAt
              : existing.lastRead,
        );
      }
    }

    return stats;
  }

  Future<BookStats?> getBookStats(String bookId) async {
    final allStats = await getAllStats();
    return allStats[bookId];
  }

  Future<int> getTotalReadingMinutes() async {
    final sessions = await getSessions(limit: 10000);
    int total = 0;
    for (final s in sessions) {
      total += s.duration.inMinutes;
    }
    return total;
  }

  Future<String> getMostReadMode() async {
    final sessions = await getSessions(limit: 1000);
    if (sessions.isEmpty) return 'paginated';
    final modeCounts = <String, int>{};
    for (final s in sessions) {
      modeCounts[s.mode] = (modeCounts[s.mode] ?? 0) + 1;
    }
    return modeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<List<String>> getFrequentErrors({int limit = 10}) async {
    final errors = _prefs.getStringList(_errorsKey) ?? [];
    final counts = <String, int>{};
    for (final e in errors) {
      final msg = e.split('|').first;
      counts[msg] = (counts[msg] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  void _saveSession(ReadingSession session) {
    final raw = _prefs.getStringList(_sessionsKey) ?? [];
    raw.add(_serializeSession(session));
    if (raw.length > 500) {
      raw.removeRange(0, raw.length - 500);
    }
    unawaited(_prefs.setStringList(_sessionsKey, raw));
  }

  String _serializeSession(ReadingSession s) {
    return '${s.bookId}|${s.startedAt.toIso8601String()}|${s.endedAt?.toIso8601String() ?? ''}|${s.pagesRead}|${s.chaptersRead}|${s.mode}';
  }

  ReadingSession? _parseSession(String raw) {
    final parts = raw.split('|');
    if (parts.length < 6) return null;
    try {
      return ReadingSession(
        bookId: parts[0],
        startedAt: DateTime.parse(parts[1]),
        endedAt: parts[2].isNotEmpty ? DateTime.parse(parts[2]) : null,
        pagesRead: int.tryParse(parts[3]) ?? 0,
        chaptersRead: int.tryParse(parts[4]) ?? 0,
        mode: parts[5],
      );
    } on Object catch (_) {
      return null;
    }
  }
}

// --- Riverpod providers ---

final readerTelemetryProvider = Provider<ReaderTelemetry>((ref) {
  throw UnimplementedError('Override in main');
});

final bookStatsProvider = FutureProvider<Map<String, BookStats>>((ref) async {
  final telemetry = ref.watch(readerTelemetryProvider);
  return telemetry.getAllStats();
});

final totalReadingMinutesProvider = FutureProvider<int>((ref) async {
  final telemetry = ref.watch(readerTelemetryProvider);
  return telemetry.getTotalReadingMinutes();
});
