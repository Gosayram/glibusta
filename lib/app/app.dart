import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform/lifecycle_service.dart';
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
    _initWindowManager();
    _initLifecycle();
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
    final isObscured = ref.watch(isObscuredProvider);
    return Stack(
      children: [
        MaterialApp.router(
          title: 'Glibusta',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: router,
          restorationScopeId: 'app',
        ),
        if (isObscured)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: Icon(Icons.menu_book, size: 48, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }
}
