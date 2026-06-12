import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings.g.dart';

@immutable
class AppSettings {
  final String baseUrl;
  final List<String> defaultMirrors;
  final List<String> customMirrors;
  final Duration requestTimeout;
  final int maxConcurrentDownloads;
  final bool enableLogging;

  List<String> get mirrors => [...defaultMirrors, ...customMirrors];

  const AppSettings({
    required this.baseUrl,
    this.defaultMirrors = const [],
    this.customMirrors = const [],
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
      defaultMirrors: mirrors,
      maxConcurrentDownloads: maxConcurrentDownloads,
    );
  }

  AppSettings copyWith({
    String? baseUrl,
    List<String>? defaultMirrors,
    List<String>? customMirrors,
    Duration? requestTimeout,
    int? maxConcurrentDownloads,
    bool? enableLogging,
  }) => AppSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    defaultMirrors: defaultMirrors ?? this.defaultMirrors,
    customMirrors: customMirrors ?? this.customMirrors,
    requestTimeout: requestTimeout ?? this.requestTimeout,
    maxConcurrentDownloads: maxConcurrentDownloads ?? this.maxConcurrentDownloads,
    enableLogging: enableLogging ?? this.enableLogging,
  );
}

@riverpod
class AppSettingsController extends _$AppSettingsController {
  @override
  AppSettings build() {
    return AppSettings.fromEnv();
  }

  void updateBaseUrl(String baseUrl) {
    state = state.copyWith(baseUrl: baseUrl);
  }

  void updateCustomMirrors(List<String> customMirrors) {
    state = state.copyWith(customMirrors: customMirrors);
  }

  void updateMaxConcurrentDownloads(int maxConcurrentDownloads) {
    state = state.copyWith(maxConcurrentDownloads: maxConcurrentDownloads);
  }

  void updateEnableLogging(bool enableLogging) {
    state = state.copyWith(enableLogging: enableLogging);
  }
}
