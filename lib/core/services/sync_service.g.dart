// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SyncConfig _$SyncConfigFromJson(Map<String, dynamic> json) => _SyncConfig(
  url: json['url'] as String,
  username: json['username'] as String?,
  password: json['password'] as String?,
  direction: $enumDecodeNullable(_$SyncDirectionEnumMap, json['direction']) ?? SyncDirection.both,
  wifiOnly: json['wifiOnly'] as bool? ?? true,
  autoSync: json['autoSync'] as bool? ?? true,
);

Map<String, dynamic> _$SyncConfigToJson(_SyncConfig instance) => <String, dynamic>{
  'url': instance.url,
  'username': instance.username,
  'password': instance.password,
  'direction': _$SyncDirectionEnumMap[instance.direction]!,
  'wifiOnly': instance.wifiOnly,
  'autoSync': instance.autoSync,
};

const _$SyncDirectionEnumMap = {
  SyncDirection.upload: 'upload',
  SyncDirection.download: 'download',
  SyncDirection.both: 'both',
};
