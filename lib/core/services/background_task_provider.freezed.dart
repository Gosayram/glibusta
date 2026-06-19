// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'background_task_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BackgroundTask {

 String get id; BackgroundTaskType get type; BackgroundTaskStatus get status; String get message; DateTime get startedAt; DateTime? get completedAt;
/// Create a copy of BackgroundTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackgroundTaskCopyWith<BackgroundTask> get copyWith => _$BackgroundTaskCopyWithImpl<BackgroundTask>(this as BackgroundTask, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackgroundTask&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,status,message,startedAt,completedAt);

@override
String toString() {
  return 'BackgroundTask(id: $id, type: $type, status: $status, message: $message, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $BackgroundTaskCopyWith<$Res>  {
  factory $BackgroundTaskCopyWith(BackgroundTask value, $Res Function(BackgroundTask) _then) = _$BackgroundTaskCopyWithImpl;
@useResult
$Res call({
 String id, BackgroundTaskType type, BackgroundTaskStatus status, String message, DateTime startedAt, DateTime? completedAt
});




}
/// @nodoc
class _$BackgroundTaskCopyWithImpl<$Res>
    implements $BackgroundTaskCopyWith<$Res> {
  _$BackgroundTaskCopyWithImpl(this._self, this._then);

  final BackgroundTask _self;
  final $Res Function(BackgroundTask) _then;

/// Create a copy of BackgroundTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? status = null,Object? message = null,Object? startedAt = null,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BackgroundTaskType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BackgroundTaskStatus,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BackgroundTask].
extension BackgroundTaskPatterns on BackgroundTask {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackgroundTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackgroundTask() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackgroundTask value)  $default,){
final _that = this;
switch (_that) {
case _BackgroundTask():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackgroundTask value)?  $default,){
final _that = this;
switch (_that) {
case _BackgroundTask() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  BackgroundTaskType type,  BackgroundTaskStatus status,  String message,  DateTime startedAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BackgroundTask() when $default != null:
return $default(_that.id,_that.type,_that.status,_that.message,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  BackgroundTaskType type,  BackgroundTaskStatus status,  String message,  DateTime startedAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _BackgroundTask():
return $default(_that.id,_that.type,_that.status,_that.message,_that.startedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  BackgroundTaskType type,  BackgroundTaskStatus status,  String message,  DateTime startedAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _BackgroundTask() when $default != null:
return $default(_that.id,_that.type,_that.status,_that.message,_that.startedAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc


class _BackgroundTask extends BackgroundTask {
  const _BackgroundTask({required this.id, required this.type, required this.status, required this.message, required this.startedAt, this.completedAt}): super._();
  

@override final  String id;
@override final  BackgroundTaskType type;
@override final  BackgroundTaskStatus status;
@override final  String message;
@override final  DateTime startedAt;
@override final  DateTime? completedAt;

/// Create a copy of BackgroundTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackgroundTaskCopyWith<_BackgroundTask> get copyWith => __$BackgroundTaskCopyWithImpl<_BackgroundTask>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackgroundTask&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,type,status,message,startedAt,completedAt);

@override
String toString() {
  return 'BackgroundTask(id: $id, type: $type, status: $status, message: $message, startedAt: $startedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$BackgroundTaskCopyWith<$Res> implements $BackgroundTaskCopyWith<$Res> {
  factory _$BackgroundTaskCopyWith(_BackgroundTask value, $Res Function(_BackgroundTask) _then) = __$BackgroundTaskCopyWithImpl;
@override @useResult
$Res call({
 String id, BackgroundTaskType type, BackgroundTaskStatus status, String message, DateTime startedAt, DateTime? completedAt
});




}
/// @nodoc
class __$BackgroundTaskCopyWithImpl<$Res>
    implements _$BackgroundTaskCopyWith<$Res> {
  __$BackgroundTaskCopyWithImpl(this._self, this._then);

  final _BackgroundTask _self;
  final $Res Function(_BackgroundTask) _then;

/// Create a copy of BackgroundTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? status = null,Object? message = null,Object? startedAt = null,Object? completedAt = freezed,}) {
  return _then(_BackgroundTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BackgroundTaskType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BackgroundTaskStatus,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
