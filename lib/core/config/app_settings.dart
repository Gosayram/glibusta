import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings.g.dart';
part 'app_settings.freezed.dart';

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required String baseUrl,
    @Default([]) List<String> defaultMirrors,
    @Default([]) List<String> customMirrors,
    @Default(Duration(seconds: 30)) Duration requestTimeout,
    @Default(3) int maxConcurrentDownloads,
    @Default(false) bool enableLogging,
  }) = _AppSettings;
  const AppSettings._();

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

  List<String> get mirrors => [...defaultMirrors, ...customMirrors];
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
