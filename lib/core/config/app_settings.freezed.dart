// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

 String get baseUrl; List<String> get defaultMirrors; List<String> get customMirrors; Duration get requestTimeout; int get maxConcurrentDownloads; bool get enableLogging;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other.defaultMirrors, defaultMirrors)&&const DeepCollectionEquality().equals(other.customMirrors, customMirrors)&&(identical(other.requestTimeout, requestTimeout) || other.requestTimeout == requestTimeout)&&(identical(other.maxConcurrentDownloads, maxConcurrentDownloads) || other.maxConcurrentDownloads == maxConcurrentDownloads)&&(identical(other.enableLogging, enableLogging) || other.enableLogging == enableLogging));
}


@override
int get hashCode => Object.hash(runtimeType,baseUrl,const DeepCollectionEquality().hash(defaultMirrors),const DeepCollectionEquality().hash(customMirrors),requestTimeout,maxConcurrentDownloads,enableLogging);

@override
String toString() {
  return 'AppSettings(baseUrl: $baseUrl, defaultMirrors: $defaultMirrors, customMirrors: $customMirrors, requestTimeout: $requestTimeout, maxConcurrentDownloads: $maxConcurrentDownloads, enableLogging: $enableLogging)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 String baseUrl, List<String> defaultMirrors, List<String> customMirrors, Duration requestTimeout, int maxConcurrentDownloads, bool enableLogging
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseUrl = null,Object? defaultMirrors = null,Object? customMirrors = null,Object? requestTimeout = null,Object? maxConcurrentDownloads = null,Object? enableLogging = null,}) {
  return _then(_self.copyWith(
baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultMirrors: null == defaultMirrors ? _self.defaultMirrors : defaultMirrors // ignore: cast_nullable_to_non_nullable
as List<String>,customMirrors: null == customMirrors ? _self.customMirrors : customMirrors // ignore: cast_nullable_to_non_nullable
as List<String>,requestTimeout: null == requestTimeout ? _self.requestTimeout : requestTimeout // ignore: cast_nullable_to_non_nullable
as Duration,maxConcurrentDownloads: null == maxConcurrentDownloads ? _self.maxConcurrentDownloads : maxConcurrentDownloads // ignore: cast_nullable_to_non_nullable
as int,enableLogging: null == enableLogging ? _self.enableLogging : enableLogging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String baseUrl,  List<String> defaultMirrors,  List<String> customMirrors,  Duration requestTimeout,  int maxConcurrentDownloads,  bool enableLogging)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.baseUrl,_that.defaultMirrors,_that.customMirrors,_that.requestTimeout,_that.maxConcurrentDownloads,_that.enableLogging);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String baseUrl,  List<String> defaultMirrors,  List<String> customMirrors,  Duration requestTimeout,  int maxConcurrentDownloads,  bool enableLogging)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.baseUrl,_that.defaultMirrors,_that.customMirrors,_that.requestTimeout,_that.maxConcurrentDownloads,_that.enableLogging);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String baseUrl,  List<String> defaultMirrors,  List<String> customMirrors,  Duration requestTimeout,  int maxConcurrentDownloads,  bool enableLogging)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.baseUrl,_that.defaultMirrors,_that.customMirrors,_that.requestTimeout,_that.maxConcurrentDownloads,_that.enableLogging);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings extends AppSettings {
  const _AppSettings({required this.baseUrl, final  List<String> defaultMirrors = const [], final  List<String> customMirrors = const [], this.requestTimeout = const Duration(seconds: 30), this.maxConcurrentDownloads = 3, this.enableLogging = false}): _defaultMirrors = defaultMirrors,_customMirrors = customMirrors,super._();
  

@override final  String baseUrl;
 final  List<String> _defaultMirrors;
@override@JsonKey() List<String> get defaultMirrors {
  if (_defaultMirrors is EqualUnmodifiableListView) return _defaultMirrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_defaultMirrors);
}

 final  List<String> _customMirrors;
@override@JsonKey() List<String> get customMirrors {
  if (_customMirrors is EqualUnmodifiableListView) return _customMirrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_customMirrors);
}

@override@JsonKey() final  Duration requestTimeout;
@override@JsonKey() final  int maxConcurrentDownloads;
@override@JsonKey() final  bool enableLogging;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&const DeepCollectionEquality().equals(other._defaultMirrors, _defaultMirrors)&&const DeepCollectionEquality().equals(other._customMirrors, _customMirrors)&&(identical(other.requestTimeout, requestTimeout) || other.requestTimeout == requestTimeout)&&(identical(other.maxConcurrentDownloads, maxConcurrentDownloads) || other.maxConcurrentDownloads == maxConcurrentDownloads)&&(identical(other.enableLogging, enableLogging) || other.enableLogging == enableLogging));
}


@override
int get hashCode => Object.hash(runtimeType,baseUrl,const DeepCollectionEquality().hash(_defaultMirrors),const DeepCollectionEquality().hash(_customMirrors),requestTimeout,maxConcurrentDownloads,enableLogging);

@override
String toString() {
  return 'AppSettings(baseUrl: $baseUrl, defaultMirrors: $defaultMirrors, customMirrors: $customMirrors, requestTimeout: $requestTimeout, maxConcurrentDownloads: $maxConcurrentDownloads, enableLogging: $enableLogging)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 String baseUrl, List<String> defaultMirrors, List<String> customMirrors, Duration requestTimeout, int maxConcurrentDownloads, bool enableLogging
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseUrl = null,Object? defaultMirrors = null,Object? customMirrors = null,Object? requestTimeout = null,Object? maxConcurrentDownloads = null,Object? enableLogging = null,}) {
  return _then(_AppSettings(
baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultMirrors: null == defaultMirrors ? _self._defaultMirrors : defaultMirrors // ignore: cast_nullable_to_non_nullable
as List<String>,customMirrors: null == customMirrors ? _self._customMirrors : customMirrors // ignore: cast_nullable_to_non_nullable
as List<String>,requestTimeout: null == requestTimeout ? _self.requestTimeout : requestTimeout // ignore: cast_nullable_to_non_nullable
as Duration,maxConcurrentDownloads: null == maxConcurrentDownloads ? _self.maxConcurrentDownloads : maxConcurrentDownloads // ignore: cast_nullable_to_non_nullable
as int,enableLogging: null == enableLogging ? _self.enableLogging : enableLogging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
