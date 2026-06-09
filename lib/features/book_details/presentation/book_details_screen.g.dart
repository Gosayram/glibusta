// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_details_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookDetails)
final bookDetailsProvider = BookDetailsFamily._();

final class BookDetailsProvider
    extends $FunctionalProvider<AsyncValue<BookDetails>, BookDetails, FutureOr<BookDetails>>
    with $FutureModifier<BookDetails>, $FutureProvider<BookDetails> {
  BookDetailsProvider._({
    required BookDetailsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bookDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookDetailsHash();

  @override
  String toString() {
    return r'bookDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BookDetails> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookDetails> create(Ref ref) {
    final argument = this.argument as String;
    return bookDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookDetailsHash() => r'1c3bb9b01d91d44b288d7d5ac20c857644b0679e';

final class BookDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BookDetails>, String> {
  BookDetailsFamily._()
    : super(
        retry: null,
        name: r'bookDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BookDetailsProvider call(String bookId) => BookDetailsProvider._(argument: bookId, from: this);

  @override
  String toString() => r'bookDetailsProvider';
}
