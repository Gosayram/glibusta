// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(continueReadingBooks)
final continueReadingBooksProvider = ContinueReadingBooksProvider._();

final class ContinueReadingBooksProvider
    extends $FunctionalProvider<AsyncValue<List<Book>>, List<Book>, FutureOr<List<Book>>>
    with $FutureModifier<List<Book>>, $FutureProvider<List<Book>> {
  ContinueReadingBooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueReadingBooksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueReadingBooksHash();

  @$internal
  @override
  $FutureProviderElement<List<Book>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Book>> create(Ref ref) {
    return continueReadingBooks(ref);
  }
}

String _$continueReadingBooksHash() => r'a75f223543935e098dbc3140296c94d2c0a1355e';
