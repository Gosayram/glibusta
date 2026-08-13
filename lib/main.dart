import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/bootstrap/app_provider_observer.dart';
import 'core/logging/app_logger.dart';
import 'core/telemetry/reader_telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Animate.defaultDuration = 300.ms;
  Animate.defaultCurve = Curves.easeOut;
  if (kDebugMode) {
    Animate.restartOnHotReload = true;
  }
  await AppBootstrap.initApp(
    appRunner: () => runZonedGuarded(
      () => runApp(
        ProviderScope(
          overrides: [
            readerTelemetryProvider.overrideWithValue(
              ReaderTelemetry(AppBootstrap.prefs, AppLogger()),
            ),
          ],
          observers: [AppProviderObserver()],
          child: const GlibustaApp(),
        ),
      ),
      (error, stack) {
        AppLogger().severe('Async error', error: error, st: stack);
      },
    ),
  );
}
