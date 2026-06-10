import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> init() async {
    await dotenv.load();
    Intl.defaultLocale = 'ru';
    _configureErrorHandlers();
    _configureImageCache();
  }

  static void _configureErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kReleaseMode) {
        unawaited(Sentry.captureException(details.exception, stackTrace: details.stack));
      }
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      if (kReleaseMode) {
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      }
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
    cache.maximumSizeBytes = 80 << 20; // 80 MB
  }

  static Future<void> initSentry({required void Function() appRunner}) async {
    final dsn = dotenv.maybeGet('SENTRY_DSN');
    if (kReleaseMode && dsn != null && dsn.isNotEmpty) {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
        },
        appRunner: appRunner,
      );
    } else {
      appRunner();
    }
  }
}
