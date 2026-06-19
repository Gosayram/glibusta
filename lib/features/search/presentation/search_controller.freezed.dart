// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchState {

 List<Book> get books; List<SearchAuthorResult> get authors; bool get isLoading; String? get error; bool get hasMore; int get currentPage; String get lastQuery; List<String> get history; SearchFilters get filters;
/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchStateCopyWith<SearchState> get copyWith => _$SearchStateCopyWithImpl<SearchState>(this as SearchState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchState&&const DeepCollectionEquality().equals(other.books, books)&&const DeepCollectionEquality().equals(other.authors, authors)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.lastQuery, lastQuery) || other.lastQuery == lastQuery)&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.filters, filters) || other.filters == filters));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(books),const DeepCollectionEquality().hash(authors),isLoading,error,hasMore,currentPage,lastQuery,const DeepCollectionEquality().hash(history),filters);

@override
String toString() {
  return 'SearchState(books: $books, authors: $authors, isLoading: $isLoading, error: $error, hasMore: $hasMore, currentPage: $currentPage, lastQuery: $lastQuery, history: $history, filters: $filters)';
}


}

/// @nodoc
abstract mixin class $SearchStateCopyWith<$Res>  {
  factory $SearchStateCopyWith(SearchState value, $Res Function(SearchState) _then) = _$SearchStateCopyWithImpl;
@useResult
$Res call({
 List<Book> books, List<SearchAuthorResult> authors, bool isLoading, String? error, bool hasMore, int currentPage, String lastQuery, List<String> history, SearchFilters filters
});


$SearchFiltersCopyWith<$Res> get filters;

}
/// @nodoc
class _$SearchStateCopyWithImpl<$Res>
    implements $SearchStateCopyWith<$Res> {
  _$SearchStateCopyWithImpl(this._self, this._then);

  final SearchState _self;
  final $Res Function(SearchState) _then;

/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? books = null,Object? authors = null,Object? isLoading = null,Object? error = freezed,Object? hasMore = null,Object? currentPage = null,Object? lastQuery = null,Object? history = null,Object? filters = null,}) {
  return _then(_self.copyWith(
books: null == books ? _self.books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,authors: null == authors ? _self.authors : authors // ignore: cast_nullable_to_non_nullable
as List<SearchAuthorResult>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,lastQuery: null == lastQuery ? _self.lastQuery : lastQuery // ignore: cast_nullable_to_non_nullable
as String,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<String>,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as SearchFilters,
  ));
}
/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchFiltersCopyWith<$Res> get filters {
  
  return $SearchFiltersCopyWith<$Res>(_self.filters, (value) {
    return _then(_self.copyWith(filters: value));
  });
}
}


/// Adds pattern-matching-related methods to [SearchState].
extension SearchStatePatterns on SearchState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchState value)  $default,){
final _that = this;
switch (_that) {
case _SearchState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchState value)?  $default,){
final _that = this;
switch (_that) {
case _SearchState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Book> books,  List<SearchAuthorResult> authors,  bool isLoading,  String? error,  bool hasMore,  int currentPage,  String lastQuery,  List<String> history,  SearchFilters filters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchState() when $default != null:
return $default(_that.books,_that.authors,_that.isLoading,_that.error,_that.hasMore,_that.currentPage,_that.lastQuery,_that.history,_that.filters);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Book> books,  List<SearchAuthorResult> authors,  bool isLoading,  String? error,  bool hasMore,  int currentPage,  String lastQuery,  List<String> history,  SearchFilters filters)  $default,) {final _that = this;
switch (_that) {
case _SearchState():
return $default(_that.books,_that.authors,_that.isLoading,_that.error,_that.hasMore,_that.currentPage,_that.lastQuery,_that.history,_that.filters);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Book> books,  List<SearchAuthorResult> authors,  bool isLoading,  String? error,  bool hasMore,  int currentPage,  String lastQuery,  List<String> history,  SearchFilters filters)?  $default,) {final _that = this;
switch (_that) {
case _SearchState() when $default != null:
return $default(_that.books,_that.authors,_that.isLoading,_that.error,_that.hasMore,_that.currentPage,_that.lastQuery,_that.history,_that.filters);case _:
  return null;

}
}

}

/// @nodoc


class _SearchState extends SearchState {
  const _SearchState({final  List<Book> books = const [], final  List<SearchAuthorResult> authors = const [], this.isLoading = false, this.error, this.hasMore = false, this.currentPage = 0, this.lastQuery = '', final  List<String> history = const [], this.filters = const SearchFilters()}): _books = books,_authors = authors,_history = history,super._();
  

 final  List<Book> _books;
@override@JsonKey() List<Book> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}

 final  List<SearchAuthorResult> _authors;
@override@JsonKey() List<SearchAuthorResult> get authors {
  if (_authors is EqualUnmodifiableListView) return _authors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_authors);
}

@override@JsonKey() final  bool isLoading;
@override final  String? error;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  int currentPage;
@override@JsonKey() final  String lastQuery;
 final  List<String> _history;
@override@JsonKey() List<String> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override@JsonKey() final  SearchFilters filters;

/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchStateCopyWith<_SearchState> get copyWith => __$SearchStateCopyWithImpl<_SearchState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchState&&const DeepCollectionEquality().equals(other._books, _books)&&const DeepCollectionEquality().equals(other._authors, _authors)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.lastQuery, lastQuery) || other.lastQuery == lastQuery)&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.filters, filters) || other.filters == filters));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_books),const DeepCollectionEquality().hash(_authors),isLoading,error,hasMore,currentPage,lastQuery,const DeepCollectionEquality().hash(_history),filters);

@override
String toString() {
  return 'SearchState(books: $books, authors: $authors, isLoading: $isLoading, error: $error, hasMore: $hasMore, currentPage: $currentPage, lastQuery: $lastQuery, history: $history, filters: $filters)';
}


}

/// @nodoc
abstract mixin class _$SearchStateCopyWith<$Res> implements $SearchStateCopyWith<$Res> {
  factory _$SearchStateCopyWith(_SearchState value, $Res Function(_SearchState) _then) = __$SearchStateCopyWithImpl;
@override @useResult
$Res call({
 List<Book> books, List<SearchAuthorResult> authors, bool isLoading, String? error, bool hasMore, int currentPage, String lastQuery, List<String> history, SearchFilters filters
});


@override $SearchFiltersCopyWith<$Res> get filters;

}
/// @nodoc
class __$SearchStateCopyWithImpl<$Res>
    implements _$SearchStateCopyWith<$Res> {
  __$SearchStateCopyWithImpl(this._self, this._then);

  final _SearchState _self;
  final $Res Function(_SearchState) _then;

/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? books = null,Object? authors = null,Object? isLoading = null,Object? error = freezed,Object? hasMore = null,Object? currentPage = null,Object? lastQuery = null,Object? history = null,Object? filters = null,}) {
  return _then(_SearchState(
books: null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<Book>,authors: null == authors ? _self._authors : authors // ignore: cast_nullable_to_non_nullable
as List<SearchAuthorResult>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,lastQuery: null == lastQuery ? _self.lastQuery : lastQuery // ignore: cast_nullable_to_non_nullable
as String,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<String>,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as SearchFilters,
  ));
}

/// Create a copy of SearchState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchFiltersCopyWith<$Res> get filters {
  
  return $SearchFiltersCopyWith<$Res>(_self.filters, (value) {
    return _then(_self.copyWith(filters: value));
  });
}
}

// dart format on
