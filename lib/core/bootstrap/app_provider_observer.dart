import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

final class AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger().warning('[Provider FAIL] ${context.provider.name}: $error', name: 'Provider');
  }
}
