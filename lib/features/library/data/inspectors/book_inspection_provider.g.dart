// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_inspection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookFileInspector)
final bookFileInspectorProvider = BookFileInspectorProvider._();

final class BookFileInspectorProvider
    extends $FunctionalProvider<BookFileInspector, BookFileInspector, BookFileInspector>
    with $Provider<BookFileInspector> {
  BookFileInspectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookFileInspectorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookFileInspectorHash();

  @$internal
  @override
  $ProviderElement<BookFileInspector> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookFileInspector create(Ref ref) {
    return bookFileInspector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookFileInspector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookFileInspector>(value),
    );
  }
}

String _$bookFileInspectorHash() => r'b35f9fad3a3c3c728a7d9d3ed6ca87c876df4856';

@ProviderFor(bookFileInspection)
final bookFileInspectionProvider = BookFileInspectionFamily._();

final class BookFileInspectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookFileInspectionResult>,
          BookFileInspectionResult,
          FutureOr<BookFileInspectionResult>
        >
    with $FutureModifier<BookFileInspectionResult>, $FutureProvider<BookFileInspectionResult> {
  BookFileInspectionProvider._({
    required BookFileInspectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bookFileInspectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookFileInspectionHash();

  @override
  String toString() {
    return r'bookFileInspectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BookFileInspectionResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookFileInspectionResult> create(Ref ref) {
    final argument = this.argument as String;
    return bookFileInspection(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookFileInspectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookFileInspectionHash() => r'4b3e587715ef50f44f2140bafb3c8bc143348030';

final class BookFileInspectionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BookFileInspectionResult>, String> {
  BookFileInspectionFamily._()
    : super(
        retry: null,
        name: r'bookFileInspectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BookFileInspectionProvider call(String path) =>
      BookFileInspectionProvider._(argument: path, from: this);

  @override
  String toString() => r'bookFileInspectionProvider';
}
