// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_tab.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReaderTabImpl _$$ReaderTabImplFromJson(Map<String, dynamic> json) =>
    _$ReaderTabImpl(
      label: json['label'] as String,
      fullName: json['fullName'] as String,
      contentFileId: json['contentFileId'] as String?,
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      pageStart: (json['pageStart'] as num?)?.toInt() ?? 0,
      pageEnd: (json['pageEnd'] as num?)?.toInt() ?? 1,
      entryStart: (json['entryStart'] as num?)?.toInt() ?? 0,
      nodeKey: json['nodeKey'] as String?,
      paliName: json['paliName'] as String?,
      sinhalaName: json['sinhalaName'] as String?,
      textId: json['textId'] as String?,
      panes: (json['panes'] as List<dynamic>?)
              ?.map((e) => ReaderPane.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      layout: $enumDecodeNullable(_$ReaderLayoutEnumMap, json['layout']) ??
          ReaderLayout.paliOnly,
      splitRatio: (json['splitRatio'] as num?)?.toDouble() ?? 0.5,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$ReaderTabImplToJson(_$ReaderTabImpl instance) =>
    <String, dynamic>{
      'label': instance.label,
      'fullName': instance.fullName,
      'contentFileId': instance.contentFileId,
      'pageIndex': instance.pageIndex,
      'pageStart': instance.pageStart,
      'pageEnd': instance.pageEnd,
      'entryStart': instance.entryStart,
      'nodeKey': instance.nodeKey,
      'paliName': instance.paliName,
      'sinhalaName': instance.sinhalaName,
      'textId': instance.textId,
      'panes': instance.panes,
      'layout': _$ReaderLayoutEnumMap[instance.layout]!,
      'splitRatio': instance.splitRatio,
      'scrollOffset': instance.scrollOffset,
    };

const _$ReaderLayoutEnumMap = {
  ReaderLayout.paliOnly: 'paliOnly',
  ReaderLayout.sinhalaOnly: 'sinhalaOnly',
  ReaderLayout.sideBySide: 'sideBySide',
  ReaderLayout.stacked: 'stacked',
};
