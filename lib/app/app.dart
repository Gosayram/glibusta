import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform/lifecycle_service.dart';
import '../core/utils/platform_detector.dart';
import 'router.dart';
import 'theme.dart';

final isObscuredProvider = NotifierProvider<IsObscuredNotifier, bool>(IsObscuredNotifier.new);

class IsObscuredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void obscure() => state = true;
  void reveal() => state = false;
}

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
    _initPlatform();
    _initLifecycle();
  }

  void _initPlatform() {
    if (PlatformDetector.isDesktop) {
      unawaited(_initWindowManager());
    }
    if (PlatformDetector.isAndroid) {
      _initAndroidEdgeToEdge();
    }
  }

  void _initAndroidEdgeToEdge() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _initLifecycle() {
    final service = ref.read(lifecycleServiceProvider);
    _lifecycleObserver = LifecycleObserver(service);
    service.setCallback(LifecycleEvent.pause, () {
      ref.read(isObscuredProvider.notifier).obscure();
    });
    service.setCallback(LifecycleEvent.inactive, () {
      ref.read(isObscuredProvider.notifier).obscure();
    });
    service.setCallback(LifecycleEvent.resume, () {
      ref.read(isObscuredProvider.notifier).reveal();
    });
  }

  Future<void> _initWindowManager() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 620),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
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
    final isObscured = ref.watch(isObscuredProvider);
    return DynamicColorBuilder(
      builder: (ColorScheme? dynamicLight, ColorScheme? dynamicDark) {
        final lightTheme = dynamicLight != null
            ? AppTheme.lightTheme.copyWith(
                colorScheme: dynamicLight,
              )
            : AppTheme.lightTheme;
        final darkTheme = dynamicDark != null
            ? AppTheme.darkTheme.copyWith(
                colorScheme: dynamicDark,
              )
            : AppTheme.darkTheme;
        return MaterialApp.router(
          title: 'Glibusta',
          theme: lightTheme,
          darkTheme: darkTheme,
          routerConfig: router,
          restorationScopeId: 'app',
          builder: (context, child) {
            if (!isObscured) return child ?? const SizedBox.shrink();
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                Positioned.fill(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Icon(
                        Icons.menu_book,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
