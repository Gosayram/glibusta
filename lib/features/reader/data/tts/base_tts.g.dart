// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_tts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TtsVoice _$TtsVoiceFromJson(Map<String, dynamic> json) => TtsVoice(
  id: json['id'] as String,
  name: json['name'] as String,
  language: json['language'] as String,
  gender: json['gender'] as String?,
);

Map<String, dynamic> _$TtsVoiceToJson(TtsVoice instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'language': instance.language,
  'gender': instance.gender,
};

TtsSettings _$TtsSettingsFromJson(Map<String, dynamic> json) => TtsSettings(
  volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
  rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
  pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
  voiceId: json['voiceId'] as String?,
  language: json['language'] as String? ?? 'ru-RU',
);

Map<String, dynamic> _$TtsSettingsToJson(TtsSettings instance) => <String, dynamic>{
  'volume': instance.volume,
  'rate': instance.rate,
  'pitch': instance.pitch,
  'voiceId': instance.voiceId,
  'language': instance.language,
};
