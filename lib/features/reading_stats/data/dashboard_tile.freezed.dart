// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_tile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DashboardTile {

 String get id; DashboardTileType get type; int get order;
/// Create a copy of DashboardTile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardTileCopyWith<DashboardTile> get copyWith => _$DashboardTileCopyWithImpl<DashboardTile>(this as DashboardTile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardTile&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.order, order) || other.order == order));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,order);

@override
String toString() {
  return 'DashboardTile(id: $id, type: $type, order: $order)';
}


}

/// @nodoc
abstract mixin class $DashboardTileCopyWith<$Res>  {
  factory $DashboardTileCopyWith(DashboardTile value, $Res Function(DashboardTile) _then) = _$DashboardTileCopyWithImpl;
@useResult
$Res call({
 String id, DashboardTileType type, int order
});




}
/// @nodoc
class _$DashboardTileCopyWithImpl<$Res>
    implements $DashboardTileCopyWith<$Res> {
  _$DashboardTileCopyWithImpl(this._self, this._then);

  final DashboardTile _self;
  final $Res Function(DashboardTile) _then;

/// Create a copy of DashboardTile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? order = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as DashboardTileType,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardTile].
extension DashboardTilePatterns on DashboardTile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardTile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardTile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardTile value)  $default,){
final _that = this;
switch (_that) {
case _DashboardTile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardTile value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardTile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DashboardTileType type,  int order)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardTile() when $default != null:
return $default(_that.id,_that.type,_that.order);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DashboardTileType type,  int order)  $default,) {final _that = this;
switch (_that) {
case _DashboardTile():
return $default(_that.id,_that.type,_that.order);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DashboardTileType type,  int order)?  $default,) {final _that = this;
switch (_that) {
case _DashboardTile() when $default != null:
return $default(_that.id,_that.type,_that.order);case _:
  return null;

}
}

}

/// @nodoc


class _DashboardTile extends DashboardTile {
  const _DashboardTile({required this.id, required this.type, this.order = 0}): super._();
  

@override final  String id;
@override final  DashboardTileType type;
@override@JsonKey() final  int order;

/// Create a copy of DashboardTile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardTileCopyWith<_DashboardTile> get copyWith => __$DashboardTileCopyWithImpl<_DashboardTile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardTile&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.order, order) || other.order == order));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,order);

@override
String toString() {
  return 'DashboardTile(id: $id, type: $type, order: $order)';
}


}

/// @nodoc
abstract mixin class _$DashboardTileCopyWith<$Res> implements $DashboardTileCopyWith<$Res> {
  factory _$DashboardTileCopyWith(_DashboardTile value, $Res Function(_DashboardTile) _then) = __$DashboardTileCopyWithImpl;
@override @useResult
$Res call({
 String id, DashboardTileType type, int order
});




}
/// @nodoc
class __$DashboardTileCopyWithImpl<$Res>
    implements _$DashboardTileCopyWith<$Res> {
  __$DashboardTileCopyWithImpl(this._self, this._then);

  final _DashboardTile _self;
  final $Res Function(_DashboardTile) _then;

/// Create a copy of DashboardTile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? order = null,}) {
  return _then(_DashboardTile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as DashboardTileType,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
