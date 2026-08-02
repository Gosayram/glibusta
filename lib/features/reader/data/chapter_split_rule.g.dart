// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_split_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChapterSplitRule _$ChapterSplitRuleFromJson(Map<String, dynamic> json) =>
    ChapterSplitRule(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      isPreset: json['isPreset'] as bool? ?? false,
      isRegex: json['isRegex'] as bool? ?? true,
    );

Map<String, dynamic> _$ChapterSplitRuleToJson(ChapterSplitRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'pattern': instance.pattern,
      'isPreset': instance.isPreset,
      'isRegex': instance.isRegex,
    };
