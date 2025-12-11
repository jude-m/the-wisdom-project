// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecentSearchImpl _$$RecentSearchImplFromJson(Map<String, dynamic> json) =>
    _$RecentSearchImpl(
      queryText: json['queryText'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$RecentSearchImplToJson(_$RecentSearchImpl instance) =>
    <String, dynamic>{
      'queryText': instance.queryText,
      'timestamp': instance.timestamp.toIso8601String(),
    };
