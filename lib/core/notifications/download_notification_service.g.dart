// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadNotificationService)
final downloadNotificationServiceProvider =
    DownloadNotificationServiceProvider._();

final class DownloadNotificationServiceProvider
    extends
        $FunctionalProvider<
          DownloadNotificationService,
          DownloadNotificationService,
          DownloadNotificationService
        >
    with $Provider<DownloadNotificationService> {
  DownloadNotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadNotificationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadNotificationServiceHash();

  @$internal
  @override
  $ProviderElement<DownloadNotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadNotificationService create(Ref ref) {
    return downloadNotificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadNotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadNotificationService>(value),
    );
  }
}

String _$downloadNotificationServiceHash() =>
    r'5ab5f38fc23b362e356c93754917779ffa88a665';
