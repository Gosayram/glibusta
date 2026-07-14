import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../core/logging/app_logger.dart';
import '../core/notifications/download_notification_service.dart';
import '../core/platform/app_platform.dart';
import '../core/platform/lifecycle_service.dart';
import '../core/platform/share_handler.dart';
import '../features/downloads/data/download_listener.dart';
import '../features/library/data/book_import_service.dart';
import '../features/library/data/library_scanner.dart';
import '../features/library/presentation/library_screen.dart' show libraryBooksProvider;
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/command_palette.dart';
import 'router.dart';
import 'theme.dart';

part 'app.g.dart';

/// Platform-appropriate page transition builder.
/// Android: PredictiveBackPageTransitionsBuilder (supports predictive back gesture)
/// Others: FadeUpwardsPageTransitionsBuilder (Material default)
PageTransitionsBuilder _platformTransitionBuilder(TargetPlatform platform) {
  if (platform == TargetPlatform.android) {
    return const PredictiveBackPageTransitionsBuilder();
  }
  return const FadeUpwardsPageTransitionsBuilder();
}

@riverpod
class IsObscuredNotifier extends _$IsObscuredNotifier {
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
  final _shareHandler = ShareHandler();
  bool _shareHandlerInitialized = false;
  bool _downloadListenerInitialized = false;
  bool _notifPermRequested = false;
  bool _libraryScanned = false;
  StreamSubscription<String>? _notificationTapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlatform();
    _initLifecycle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shareHandlerInitialized) {
      _shareHandlerInitialized = true;
      final importService = ref.read(bookImportServiceProvider);
      _shareHandler.init(context, importService);
    }
    if (!_downloadListenerInitialized) {
      _downloadListenerInitialized = true;
      final listener = ref.read(downloadListenerProvider);
      listener.startListening();
    }
    if (!_notifPermRequested && supportsPredictiveBack) {
      _notifPermRequested = true;
      unawaited(_requestNotificationPermission());
    }
    if (_notificationTapSub == null) {
      final notifService = ref.read(downloadNotificationServiceProvider);
      _notificationTapSub = notifService.onTapBookId.listen(_onNotificationTap);
    }
    if (!_libraryScanned) {
      _libraryScanned = true;
      unawaited(_scanLibrary());
    }
  }

  void _initPlatform() {
    if (supportsPredictiveBack) {
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

  static const _platform = MethodChannel('com.gosayram.glibusta/storage_bridge');

  void _onNotificationTap(String bookId) {
    if (bookId.isEmpty) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      ctx.go('/reader/$bookId');
    }
  }

  Future<void> _scanLibrary() async {
    try {
      await _ensureStoragePermission();
      final scanner = ref.read(libraryScannerProvider);
      await scanner.scanLazy();
      if (mounted) {
        ref.invalidate(libraryBooksProvider);
      }
    } on Object catch (error, stackTrace) {
      AppLogger().warning(
        'Initial library scan failed: $error',
        name: 'App',
        error: error,
        st: stackTrace,
      );
    }
  }

  Future<void> _ensureStoragePermission() async {
    try {
      final granted = await _platform.invokeMethod<bool>('checkStoragePermission');
      if (granted == true) return;
      await _platform.invokeMethod<bool>('requestStoragePermission');
    } on MissingPluginException {
      // Not on Android — ignore.
    } on PlatformException catch (error, stackTrace) {
      AppLogger().warning(
        'Storage permission channel failed: ${error.message}',
        name: 'App',
        error: error,
        st: stackTrace,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _platform.invokeMethod<bool>('requestNotificationPermission');
    } on MissingPluginException {
      // Not on Android — ignore.
    } on PlatformException catch (error, stackTrace) {
      AppLogger().warning(
        'Notification permission channel failed: ${error.message}',
        name: 'App',
        error: error,
        st: stackTrace,
      );
    }
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

  @override
  void dispose() {
    unawaited(_notificationTapSub?.cancel());
    _shareHandler.dispose();
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
    final themeMode = ref.watch(themeModeProvider);
    return DynamicColorBuilder(
      builder: (ColorScheme? dynamicLight, ColorScheme? dynamicDark) {
        final useDynamicLight = dynamicLight != null;
        final useDynamicDark = dynamicDark != null;
        final transitions = PageTransitionsTheme(
          builders: {
            for (final p in TargetPlatform.values) p: _platformTransitionBuilder(p),
          },
        );
        final lightTheme =
            AppTheme.buildLightTheme(
              useDynamicScheme: useDynamicLight,
              dynamicScheme: dynamicLight,
            ).copyWith(
              pageTransitionsTheme: transitions,
              extensions: [
                const SkeletonizerConfigData(
                  enableSwitchAnimation: true,
                ),
              ],
            );
        final darkTheme =
            AppTheme.buildDarkTheme(
              useDynamicScheme: useDynamicDark,
              dynamicScheme: dynamicDark,
            ).copyWith(
              pageTransitionsTheme: transitions,
              extensions: [
                const SkeletonizerConfigData(
                  enableSwitchAnimation: true,
                ),
              ],
            );
        return MaterialApp.router(
          title: 'Glibusta',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: router,
          restorationScopeId: 'app',
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final wrappedChild = _GlobalKeyboardShortcuts(
              key: const Key('global-keyboard-shortcuts'),
              child: child ?? const SizedBox.shrink(),
            );
            if (!isObscured) return wrappedChild;
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

class _GlobalKeyboardShortcuts extends StatefulWidget {
  final Widget child;

  const _GlobalKeyboardShortcuts({super.key, required this.child});

  @override
  State<_GlobalKeyboardShortcuts> createState() => _GlobalKeyboardShortcutsState();
}

class _GlobalKeyboardShortcutsState extends State<_GlobalKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_hasCommandModifier()) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      CommandPalette.show(context);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF && !_isReaderRoute()) {
      context.go('/search');
      return true;
    }

    return false;
  }

  bool _hasCommandModifier() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.meta) || keys.contains(LogicalKeyboardKey.control);
  }

  bool _isReaderRoute() {
    try {
      return GoRouterState.of(context).uri.path.startsWith('/reader/');
    } on Object {
      return false;
    }
  }
}
