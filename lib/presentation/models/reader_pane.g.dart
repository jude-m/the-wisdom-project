// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_pane.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReaderPaneImpl _$$ReaderPaneImplFromJson(Map<String, dynamic> json) =>
    _$ReaderPaneImpl(
      paneId: json['paneId'] as String,
      layerId: json['layerId'] as String,
      isVisible: json['isVisible'] as bool? ?? true,
    );

Map<String, dynamic> _$$ReaderPaneImplToJson(_$ReaderPaneImpl instance) =>
    <String, dynamic>{
      'paneId': instance.paneId,
      'layerId': instance.layerId,
      'isVisible': instance.isVisible,
    };
