import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../logging/app_logger.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> init() async {
    await dotenv.load();
    if (!dotenv.isEveryDefined(['BASE_URL'])) {
      throw StateError(
        'Required environment variable BASE_URL is not defined. '
        'Check your .env file.',
      );
    }
    unawaited(pdfrxFlutterInitialize());
    Intl.defaultLocale = 'ru';
    _configureErrorHandlers();
    _configureImageCache();
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
    cache.maximumSizeBytes = 80 << 20;
  }

  static Future<void> initApp({required void Function() appRunner}) async {
    await init();
    appRunner();
  }
}
