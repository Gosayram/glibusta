import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform/lifecycle_service.dart';
import 'router.dart';
import 'theme.dart';

class GlibustaApp extends ConsumerStatefulWidget {
  const GlibustaApp({super.key});

  @override
  ConsumerState<GlibustaApp> createState() => _GlibustaAppState();
}

class _GlibustaAppState extends ConsumerState<GlibustaApp> with WidgetsBindingObserver {
  late final LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWindowManager();
    _initLifecycle();
  }

  void _initLifecycle() {
    final service = ref.read(lifecycleServiceProvider);
    _lifecycleObserver = LifecycleObserver(service);
    service.setCallback(LifecycleEvent.pause, () {
      ref.read(lifecycleServiceProvider);
    });
  }

  Future<void> _initWindowManager() async {
    await windowManager.ensureInitialized();

    final WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 620),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleObserver.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Glibusta',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      restorationScopeId: 'app',
    );
  }
}
