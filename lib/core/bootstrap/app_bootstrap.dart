import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/rust/api/frb_generated.dart';
import '../logging/app_logger.dart';
import '../services/sync_service.dart';

class AppBootstrap {
  AppBootstrap._();

  /// SharedPreferences instance loaded before runApp; used for provider
  /// overrides (e.g. readerTelemetryProvider).
  static late final SharedPreferences prefs;

  static Future<void> init() async {
    await RustLib.init();
    await dotenv.load();
    if (!dotenv.isEveryDefined(['BASE_URL'])) {
      throw StateError(
        'Required environment variable BASE_URL is not defined. '
        'Check your .env file.',
      );
    }
    prefs = await SharedPreferences.getInstance();
    Intl.defaultLocale = 'ru';
    _configureErrorHandlers();
    _configureImageCache();
    // STR-4.2: initialize background sync without delaying app startup.
    unawaited(
      SyncService.initialize().catchError((Object error, StackTrace stackTrace) {
        AppLogger().warning(
          'Background sync initialization failed',
          name: 'Bootstrap',
          error: error,
          st: stackTrace,
        );
      }),
    );
  }

  static void _configureErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      AppLogger().severe('Uncaught error: $error', name: 'Bootstrap', error: error, st: stackTrace);
      return true;
    };
    ErrorWidget.builder = (details) {
      return Material(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Ошибка: ${details.exceptionAsString()}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    };
  }

  static void _configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 100;
    cache.maximumSizeBytes = 50 << 20;
  }

  static Future<void> initApp({required void Function() appRunner}) async {
    await init();
    appRunner();
  }
}
