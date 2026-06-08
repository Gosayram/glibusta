import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

@immutable
class AppSettings {
  final String baseUrl;
  final List<String> mirrors;
  final Duration requestTimeout;
  final int maxConcurrentDownloads;
  final bool enableLogging;

  const AppSettings({
    this.baseUrl = 'https://flibusta.site',
    this.mirrors = const [
      'https://flibusta.me',
      'https://flibusta.is',
      'https://flibusta.top',
    ],
    this.requestTimeout = const Duration(seconds: 30),
    this.maxConcurrentDownloads = 3,
    this.enableLogging = false,
  });

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
  return const AppSettings();
});
