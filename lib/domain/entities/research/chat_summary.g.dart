// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatSummaryImpl _$$ChatSummaryImplFromJson(Map<String, dynamic> json) =>
    _$ChatSummaryImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      mode: $enumDecodeNullable(_$ResearchModeEnumMap, json['mode']) ??
          ResearchMode.fast,
    );

Map<String, dynamic> _$$ChatSummaryImplToJson(_$ChatSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'mode': _$ResearchModeEnumMap[instance.mode]!,
    };

const _$ResearchModeEnumMap = {
  ResearchMode.fast: 'fast',
  ResearchMode.thinking: 'thinking',
};
