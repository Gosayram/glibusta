import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/bootstrap/app_provider_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.init();

  await AppBootstrap.initSentry(
    appRunner: () => runApp(
      ProviderScope(
        observers: [AppProviderObserver()],
        child: const GlibustaApp(),
      ),
    ),
  );
}
