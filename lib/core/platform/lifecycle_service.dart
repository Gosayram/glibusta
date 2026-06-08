import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lifecycleServiceProvider = Provider<LifecycleService>((ref) {
  return LifecycleService(ref);
});

class LifecycleService {
  final Ref ref;
  final _callbacks = <LifecycleEvent, List<VoidCallback>>{};

  LifecycleService(this.ref);

  void setCallback(LifecycleEvent event, VoidCallback callback) {
    _callbacks.putIfAbsent(event, () => []).add(callback);
  }

  void handleEvent(LifecycleEvent event) {
    for (final callback in _callbacks[event] ?? []) {
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
