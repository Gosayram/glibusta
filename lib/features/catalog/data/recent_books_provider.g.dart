// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_books_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recentBooks)
final recentBooksProvider = RecentBooksProvider._();

final class RecentBooksProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecentBooksResponse>,
          RecentBooksResponse,
          FutureOr<RecentBooksResponse>
        >
    with
        $FutureModifier<RecentBooksResponse>,
        $FutureProvider<RecentBooksResponse> {
  RecentBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentBooksHash();

  @$internal
  @override
  $FutureProviderElement<RecentBooksResponse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RecentBooksResponse> create(Ref ref) {
    return recentBooks(ref);
  }
}

String _$recentBooksHash() => r'6f09be0ab04d820fd6f5cc426f181ee5f3a625e4';
