// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AskAnswerImpl _$$AskAnswerImplFromJson(Map<String, dynamic> json) =>
    _$AskAnswerImpl(
      answer: json['answer'] as String,
      lang: json['lang'] as String,
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => Citation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$AskAnswerImplToJson(_$AskAnswerImpl instance) =>
    <String, dynamic>{
      'answer': instance.answer,
      'lang': instance.lang,
      'citations': instance.citations,
    };
