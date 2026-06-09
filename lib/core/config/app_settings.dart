import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/legacy.dart';

@immutable
class AppSettings {
  final String baseUrl;
  final List<String> mirrors;
  final Duration requestTimeout;
  final int maxConcurrentDownloads;
  final bool enableLogging;

  const AppSettings({
    required this.baseUrl,
    this.mirrors = const [],
    this.requestTimeout = const Duration(seconds: 30),
    this.maxConcurrentDownloads = 3,
    this.enableLogging = false,
  });

  factory AppSettings.fromEnv() {
    final baseUrl = dotenv.env['BASE_URL'] ?? '';
    final mirrorsRaw = dotenv.env['MIRRORS'] ?? '';
    final mirrors = mirrorsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final concurrentStr = dotenv.env['CONCURRENT_DOWNLOADS'] ?? '3';
    final maxConcurrentDownloads = int.tryParse(concurrentStr) ?? 3;

    return AppSettings(
      baseUrl: baseUrl,
      mirrors: mirrors,
      maxConcurrentDownloads: maxConcurrentDownloads,
    );
  }

  AppSettings copyWith({
    String? baseUrl,
    List<String>? mirrors,
    Duration? requestTimeout,
    int? maxConcurrentDownloads,
    bool? enableLogging,
  }) => AppSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    mirrors: mirrors ?? this.mirrors,
    requestTimeout: requestTimeout ?? this.requestTimeout,
    maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
    enableLogging: enableLogging ?? this.enableLogging,
  );
}

final appSettingsProvider = StateProvider<AppSettings>((ref) {
  return AppSettings.fromEnv();
});
