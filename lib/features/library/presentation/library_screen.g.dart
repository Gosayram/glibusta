// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(libraryBooks)
final libraryBooksProvider = LibraryBooksProvider._();

final class LibraryBooksProvider
    extends $FunctionalProvider<AsyncValue<List<Book>>, List<Book>, FutureOr<List<Book>>>
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  LibraryBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryBooksHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return libraryBooks(ref);
  }
}

String _$libraryBooksHash() => r'f545cfa699d973326feeeffa68b5388566a225d2';
