import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('[Provider FAIL] ${context.provider.name}: $error');
  }
}
