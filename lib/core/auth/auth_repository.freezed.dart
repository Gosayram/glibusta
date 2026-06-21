// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthStateData {

 bool get isAuthenticated; UserSession? get session; String? get error; bool get isLoading;
/// Create a copy of AuthStateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthStateDataCopyWith<AuthStateData> get copyWith => _$AuthStateDataCopyWithImpl<AuthStateData>(this as AuthStateData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthStateData&&(identical(other.isAuthenticated, isAuthenticated) || other.isAuthenticated == isAuthenticated)&&(identical(other.session, session) || other.session == session)&&(identical(other.error, error) || other.error == error)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,isAuthenticated,session,error,isLoading);

@override
String toString() {
  return 'AuthStateData(isAuthenticated: $isAuthenticated, session: $session, error: $error, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class $AuthStateDataCopyWith<$Res>  {
  factory $AuthStateDataCopyWith(AuthStateData value, $Res Function(AuthStateData) _then) = _$AuthStateDataCopyWithImpl;
@useResult
$Res call({
 bool isAuthenticated, UserSession? session, String? error, bool isLoading
});




}
/// @nodoc
class _$AuthStateDataCopyWithImpl<$Res>
    implements $AuthStateDataCopyWith<$Res> {
  _$AuthStateDataCopyWithImpl(this._self, this._then);

  final AuthStateData _self;
  final $Res Function(AuthStateData) _then;

/// Create a copy of AuthStateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isAuthenticated = null,Object? session = freezed,Object? error = freezed,Object? isLoading = null,}) {
  return _then(_self.copyWith(
isAuthenticated: null == isAuthenticated ? _self.isAuthenticated : isAuthenticated // ignore: cast_nullable_to_non_nullable
as bool,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as UserSession?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthStateData].
extension AuthStateDataPatterns on AuthStateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthStateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthStateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthStateData value)  $default,){
final _that = this;
switch (_that) {
case _AuthStateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthStateData value)?  $default,){
final _that = this;
switch (_that) {
case _AuthStateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isAuthenticated,  UserSession? session,  String? error,  bool isLoading)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthStateData() when $default != null:
return $default(_that.isAuthenticated,_that.session,_that.error,_that.isLoading);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isAuthenticated,  UserSession? session,  String? error,  bool isLoading)  $default,) {final _that = this;
switch (_that) {
case _AuthStateData():
return $default(_that.isAuthenticated,_that.session,_that.error,_that.isLoading);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isAuthenticated,  UserSession? session,  String? error,  bool isLoading)?  $default,) {final _that = this;
switch (_that) {
case _AuthStateData() when $default != null:
return $default(_that.isAuthenticated,_that.session,_that.error,_that.isLoading);case _:
  return null;

}
}

}

/// @nodoc


class _AuthStateData extends AuthStateData {
  const _AuthStateData({this.isAuthenticated = false, this.session, this.error, this.isLoading = false}): super._();
  

@override@JsonKey() final  bool isAuthenticated;
@override final  UserSession? session;
@override final  String? error;
@override@JsonKey() final  bool isLoading;

/// Create a copy of AuthStateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthStateDataCopyWith<_AuthStateData> get copyWith => __$AuthStateDataCopyWithImpl<_AuthStateData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthStateData&&(identical(other.isAuthenticated, isAuthenticated) || other.isAuthenticated == isAuthenticated)&&(identical(other.session, session) || other.session == session)&&(identical(other.error, error) || other.error == error)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading));
}


@override
int get hashCode => Object.hash(runtimeType,isAuthenticated,session,error,isLoading);

@override
String toString() {
  return 'AuthStateData(isAuthenticated: $isAuthenticated, session: $session, error: $error, isLoading: $isLoading)';
}


}

/// @nodoc
abstract mixin class _$AuthStateDataCopyWith<$Res> implements $AuthStateDataCopyWith<$Res> {
  factory _$AuthStateDataCopyWith(_AuthStateData value, $Res Function(_AuthStateData) _then) = __$AuthStateDataCopyWithImpl;
@override @useResult
$Res call({
 bool isAuthenticated, UserSession? session, String? error, bool isLoading
});




}
/// @nodoc
class __$AuthStateDataCopyWithImpl<$Res>
    implements _$AuthStateDataCopyWith<$Res> {
  __$AuthStateDataCopyWithImpl(this._self, this._then);

  final _AuthStateData _self;
  final $Res Function(_AuthStateData) _then;

/// Create a copy of AuthStateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isAuthenticated = null,Object? session = freezed,Object? error = freezed,Object? isLoading = null,}) {
  return _then(_AuthStateData(
isAuthenticated: null == isAuthenticated ? _self.isAuthenticated : isAuthenticated // ignore: cast_nullable_to_non_nullable
as bool,session: freezed == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as UserSession?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
