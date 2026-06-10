import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> init() async {
    await dotenv.load();
    Intl.defaultLocale = 'ru';
  }

  static Future<void> initSentry({required void Function() appRunner}) async {
    final dsn = dotenv.maybeGet('SENTRY_DSN');
    if (kReleaseMode && dsn != null && dsn.isNotEmpty) {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.tracesSampleRate = 1.0;
        },
        appRunner: appRunner,
      );
    } else {
      appRunner();
    }
  }
}
