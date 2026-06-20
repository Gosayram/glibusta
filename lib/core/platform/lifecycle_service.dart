import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import '../services/sync_service.dart';

final lifecycleServiceProvider = Provider<LifecycleService>((ref) {
  final service = LifecycleService(ref);
  service._setupAutoSync(ref);
  return service;
});

class LifecycleService {
  final Ref ref;
  final _callbacks = <LifecycleEvent, List<VoidCallback>>{};

  LifecycleService(this.ref);

  void _setupAutoSync(Ref ref) {
    setCallback(LifecycleEvent.pause, () {
      _triggerAutoSync(ref);
    });
    setCallback(LifecycleEvent.hide, () {
      _triggerAutoSync(ref);
    });
  }

  void _triggerAutoSync(Ref ref) {
    try {
      final syncService = ref.read(syncServiceProvider);
      if (syncService.config?.autoSync == true && syncService.status != SyncStatus.syncing) {
        unawaited(syncService.sync());
      }
    } on Object catch (e) {
      AppLogger().warning('Failed to trigger auto-sync', error: e);
    }
  }

  void setCallback(LifecycleEvent event, VoidCallback callback) {
    _callbacks.putIfAbsent(event, () => []).add(callback);
  }

  void handleEvent(LifecycleEvent event) {
    for (final callback in _callbacks[event] ?? <VoidCallback>[]) {
      callback();
    }
  }
}

enum LifecycleEvent {
  pause,
  resume,
  hide,
  inactive,
  detach,
}

class LifecycleObserver extends WidgetsBindingObserver {
  final LifecycleService service;

  LifecycleObserver(this.service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        service.handleEvent(LifecycleEvent.pause);
        break;
      case AppLifecycleState.resumed:
        service.handleEvent(LifecycleEvent.resume);
        break;
      case AppLifecycleState.hidden:
        service.handleEvent(LifecycleEvent.hide);
        break;
      case AppLifecycleState.inactive:
        service.handleEvent(LifecycleEvent.inactive);
        break;
      case AppLifecycleState.detached:
        service.handleEvent(LifecycleEvent.detach);
        break;
    }
  }
}
