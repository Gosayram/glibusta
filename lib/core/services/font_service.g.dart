// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FontModel _$FontModelFromJson(Map<String, dynamic> json) => _FontModel(
  name: json['name'] as String,
  fileName: json['fileName'] as String,
  family: json['family'] as String?,
  weight: json['weight'] == null ? FontWeight.normal : _fontWeightFromJson(json['weight']),
  style: json['style'] == null
      ? FontStyle.normal
      : _fontStyleFromJson((json['style'] as num).toInt()),
  isDownloaded: json['isDownloaded'] as bool? ?? false,
  downloadUrl: json['downloadUrl'] as String?,
  fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$FontModelToJson(_FontModel instance) => <String, dynamic>{
  'name': instance.name,
  'fileName': instance.fileName,
  'family': instance.family,
  'weight': _fontWeightToJson(instance.weight),
  'style': _fontStyleToJson(instance.style),
  'isDownloaded': instance.isDownloaded,
  'downloadUrl': instance.downloadUrl,
  'fileSize': instance.fileSize,
};
