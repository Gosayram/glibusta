// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_comments_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookCommentsService)
final bookCommentsServiceProvider = BookCommentsServiceProvider._();

final class BookCommentsServiceProvider
    extends
        $FunctionalProvider<
          BookCommentsService,
          BookCommentsService,
          BookCommentsService
        >
    with $Provider<BookCommentsService> {
  BookCommentsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookCommentsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookCommentsServiceHash();

  @$internal
  @override
  $ProviderElement<BookCommentsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookCommentsService create(Ref ref) {
    return bookCommentsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookCommentsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookCommentsService>(value),
    );
  }
}

String _$bookCommentsServiceHash() =>
    r'5cea0b4f9ab8ccc72cc6e09c7bf950cf349489e6';
