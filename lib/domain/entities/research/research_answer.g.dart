// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_answer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ResearchAnswerImpl _$$ResearchAnswerImplFromJson(Map<String, dynamic> json) =>
    _$ResearchAnswerImpl(
      answer: json['answer'] as String,
      lang: json['lang'] as String,
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => Citation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ResearchAnswerImplToJson(
        _$ResearchAnswerImpl instance) =>
    <String, dynamic>{
      'answer': instance.answer,
      'lang': instance.lang,
      'citations': instance.citations,
    };
