// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'citation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CitationImpl _$$CitationImplFromJson(Map<String, dynamic> json) =>
    _$CitationImpl(
      uid: json['uid'] as String,
      ref: json['ref'] as String,
      kind: json['kind'] as String? ?? 'canon',
      snippet: json['snippet'] as String?,
      deeplink: json['deeplink'] as String?,
    );

Map<String, dynamic> _$$CitationImplToJson(_$CitationImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'ref': instance.ref,
      'kind': instance.kind,
      'snippet': instance.snippet,
      'deeplink': instance.deeplink,
    };
