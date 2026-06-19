// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_goal_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingGoal {

 int get dailyMinutes; bool get isEnabled;
/// Create a copy of ReadingGoal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingGoalCopyWith<ReadingGoal> get copyWith => _$ReadingGoalCopyWithImpl<ReadingGoal>(this as ReadingGoal, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingGoal&&(identical(other.dailyMinutes, dailyMinutes) || other.dailyMinutes == dailyMinutes)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,dailyMinutes,isEnabled);

@override
String toString() {
  return 'ReadingGoal(dailyMinutes: $dailyMinutes, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class $ReadingGoalCopyWith<$Res>  {
  factory $ReadingGoalCopyWith(ReadingGoal value, $Res Function(ReadingGoal) _then) = _$ReadingGoalCopyWithImpl;
@useResult
$Res call({
 int dailyMinutes, bool isEnabled
});




}
/// @nodoc
class _$ReadingGoalCopyWithImpl<$Res>
    implements $ReadingGoalCopyWith<$Res> {
  _$ReadingGoalCopyWithImpl(this._self, this._then);

  final ReadingGoal _self;
  final $Res Function(ReadingGoal) _then;

/// Create a copy of ReadingGoal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dailyMinutes = null,Object? isEnabled = null,}) {
  return _then(_self.copyWith(
dailyMinutes: null == dailyMinutes ? _self.dailyMinutes : dailyMinutes // ignore: cast_nullable_to_non_nullable
as int,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingGoal].
extension ReadingGoalPatterns on ReadingGoal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingGoal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingGoal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingGoal value)  $default,){
final _that = this;
switch (_that) {
case _ReadingGoal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingGoal value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingGoal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int dailyMinutes,  bool isEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingGoal() when $default != null:
return $default(_that.dailyMinutes,_that.isEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int dailyMinutes,  bool isEnabled)  $default,) {final _that = this;
switch (_that) {
case _ReadingGoal():
return $default(_that.dailyMinutes,_that.isEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int dailyMinutes,  bool isEnabled)?  $default,) {final _that = this;
switch (_that) {
case _ReadingGoal() when $default != null:
return $default(_that.dailyMinutes,_that.isEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingGoal extends ReadingGoal {
  const _ReadingGoal({this.dailyMinutes = 30, this.isEnabled = false}): super._();
  

@override@JsonKey() final  int dailyMinutes;
@override@JsonKey() final  bool isEnabled;

/// Create a copy of ReadingGoal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingGoalCopyWith<_ReadingGoal> get copyWith => __$ReadingGoalCopyWithImpl<_ReadingGoal>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingGoal&&(identical(other.dailyMinutes, dailyMinutes) || other.dailyMinutes == dailyMinutes)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,dailyMinutes,isEnabled);

@override
String toString() {
  return 'ReadingGoal(dailyMinutes: $dailyMinutes, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class _$ReadingGoalCopyWith<$Res> implements $ReadingGoalCopyWith<$Res> {
  factory _$ReadingGoalCopyWith(_ReadingGoal value, $Res Function(_ReadingGoal) _then) = __$ReadingGoalCopyWithImpl;
@override @useResult
$Res call({
 int dailyMinutes, bool isEnabled
});




}
/// @nodoc
class __$ReadingGoalCopyWithImpl<$Res>
    implements _$ReadingGoalCopyWith<$Res> {
  __$ReadingGoalCopyWithImpl(this._self, this._then);

  final _ReadingGoal _self;
  final $Res Function(_ReadingGoal) _then;

/// Create a copy of ReadingGoal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dailyMinutes = null,Object? isEnabled = null,}) {
  return _then(_ReadingGoal(
dailyMinutes: null == dailyMinutes ? _self.dailyMinutes : dailyMinutes // ignore: cast_nullable_to_non_nullable
as int,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
