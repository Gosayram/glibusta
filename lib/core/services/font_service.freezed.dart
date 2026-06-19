// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'font_service.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FontModel {

 String get name; String get fileName; String? get family;@JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson) FontWeight get weight;@JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson) FontStyle get style; bool get isDownloaded; String? get downloadUrl; int get fileSize;
/// Create a copy of FontModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FontModelCopyWith<FontModel> get copyWith => _$FontModelCopyWithImpl<FontModel>(this as FontModel, _$identity);

  /// Serializes this FontModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FontModel&&(identical(other.name, name) || other.name == name)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.family, family) || other.family == family)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.style, style) || other.style == style)&&(identical(other.isDownloaded, isDownloaded) || other.isDownloaded == isDownloaded)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,fileName,family,weight,style,isDownloaded,downloadUrl,fileSize);

@override
String toString() {
  return 'FontModel(name: $name, fileName: $fileName, family: $family, weight: $weight, style: $style, isDownloaded: $isDownloaded, downloadUrl: $downloadUrl, fileSize: $fileSize)';
}


}

/// @nodoc
abstract mixin class $FontModelCopyWith<$Res>  {
  factory $FontModelCopyWith(FontModel value, $Res Function(FontModel) _then) = _$FontModelCopyWithImpl;
@useResult
$Res call({
 String name, String fileName, String? family,@JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson) FontWeight weight,@JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson) FontStyle style, bool isDownloaded, String? downloadUrl, int fileSize
});




}
/// @nodoc
class _$FontModelCopyWithImpl<$Res>
    implements $FontModelCopyWith<$Res> {
  _$FontModelCopyWithImpl(this._self, this._then);

  final FontModel _self;
  final $Res Function(FontModel) _then;

/// Create a copy of FontModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? fileName = null,Object? family = freezed,Object? weight = null,Object? style = null,Object? isDownloaded = null,Object? downloadUrl = freezed,Object? fileSize = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as FontWeight,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as FontStyle,isDownloaded: null == isDownloaded ? _self.isDownloaded : isDownloaded // ignore: cast_nullable_to_non_nullable
as bool,downloadUrl: freezed == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String?,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FontModel].
extension FontModelPatterns on FontModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FontModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FontModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FontModel value)  $default,){
final _that = this;
switch (_that) {
case _FontModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FontModel value)?  $default,){
final _that = this;
switch (_that) {
case _FontModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String fileName,  String? family, @JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson)  FontWeight weight, @JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson)  FontStyle style,  bool isDownloaded,  String? downloadUrl,  int fileSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FontModel() when $default != null:
return $default(_that.name,_that.fileName,_that.family,_that.weight,_that.style,_that.isDownloaded,_that.downloadUrl,_that.fileSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String fileName,  String? family, @JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson)  FontWeight weight, @JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson)  FontStyle style,  bool isDownloaded,  String? downloadUrl,  int fileSize)  $default,) {final _that = this;
switch (_that) {
case _FontModel():
return $default(_that.name,_that.fileName,_that.family,_that.weight,_that.style,_that.isDownloaded,_that.downloadUrl,_that.fileSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String fileName,  String? family, @JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson)  FontWeight weight, @JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson)  FontStyle style,  bool isDownloaded,  String? downloadUrl,  int fileSize)?  $default,) {final _that = this;
switch (_that) {
case _FontModel() when $default != null:
return $default(_that.name,_that.fileName,_that.family,_that.weight,_that.style,_that.isDownloaded,_that.downloadUrl,_that.fileSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FontModel extends FontModel {
  const _FontModel({required this.name, required this.fileName, this.family, @JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson) this.weight = FontWeight.normal, @JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson) this.style = FontStyle.normal, this.isDownloaded = false, this.downloadUrl, this.fileSize = 0}): super._();
  factory _FontModel.fromJson(Map<String, dynamic> json) => _$FontModelFromJson(json);

@override final  String name;
@override final  String fileName;
@override final  String? family;
@override@JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson) final  FontWeight weight;
@override@JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson) final  FontStyle style;
@override@JsonKey() final  bool isDownloaded;
@override final  String? downloadUrl;
@override@JsonKey() final  int fileSize;

/// Create a copy of FontModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FontModelCopyWith<_FontModel> get copyWith => __$FontModelCopyWithImpl<_FontModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FontModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FontModel&&(identical(other.name, name) || other.name == name)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.family, family) || other.family == family)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.style, style) || other.style == style)&&(identical(other.isDownloaded, isDownloaded) || other.isDownloaded == isDownloaded)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,fileName,family,weight,style,isDownloaded,downloadUrl,fileSize);

@override
String toString() {
  return 'FontModel(name: $name, fileName: $fileName, family: $family, weight: $weight, style: $style, isDownloaded: $isDownloaded, downloadUrl: $downloadUrl, fileSize: $fileSize)';
}


}

/// @nodoc
abstract mixin class _$FontModelCopyWith<$Res> implements $FontModelCopyWith<$Res> {
  factory _$FontModelCopyWith(_FontModel value, $Res Function(_FontModel) _then) = __$FontModelCopyWithImpl;
@override @useResult
$Res call({
 String name, String fileName, String? family,@JsonKey(toJson: _fontWeightToJson, fromJson: _fontWeightFromJson) FontWeight weight,@JsonKey(toJson: _fontStyleToJson, fromJson: _fontStyleFromJson) FontStyle style, bool isDownloaded, String? downloadUrl, int fileSize
});




}
/// @nodoc
class __$FontModelCopyWithImpl<$Res>
    implements _$FontModelCopyWith<$Res> {
  __$FontModelCopyWithImpl(this._self, this._then);

  final _FontModel _self;
  final $Res Function(_FontModel) _then;

/// Create a copy of FontModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? fileName = null,Object? family = freezed,Object? weight = null,Object? style = null,Object? isDownloaded = null,Object? downloadUrl = freezed,Object? fileSize = null,}) {
  return _then(_FontModel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,weight: null == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as FontWeight,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as FontStyle,isDownloaded: null == isDownloaded ? _self.isDownloaded : isDownloaded // ignore: cast_nullable_to_non_nullable
as bool,downloadUrl: freezed == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String?,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
