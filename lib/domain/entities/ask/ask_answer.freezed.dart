// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ask_answer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AskAnswer _$AskAnswerFromJson(Map<String, dynamic> json) {
  return _AskAnswer.fromJson(json);
}

/// @nodoc
mixin _$AskAnswer {
  /// The answer prose, in the same language as the question.
  String get answer => throw _privateConstructorUsedError;

  /// "si" | "en".
  String get lang => throw _privateConstructorUsedError;

  /// Sources the answer is grounded on (may be empty).
  List<Citation> get citations => throw _privateConstructorUsedError;

  /// Serializes this AskAnswer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AskAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AskAnswerCopyWith<AskAnswer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AskAnswerCopyWith<$Res> {
  factory $AskAnswerCopyWith(AskAnswer value, $Res Function(AskAnswer) then) =
      _$AskAnswerCopyWithImpl<$Res, AskAnswer>;
  @useResult
  $Res call({String answer, String lang, List<Citation> citations});
}

/// @nodoc
class _$AskAnswerCopyWithImpl<$Res, $Val extends AskAnswer>
    implements $AskAnswerCopyWith<$Res> {
  _$AskAnswerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AskAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? lang = null,
    Object? citations = null,
  }) {
    return _then(_value.copyWith(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      lang: null == lang
          ? _value.lang
          : lang // ignore: cast_nullable_to_non_nullable
              as String,
      citations: null == citations
          ? _value.citations
          : citations // ignore: cast_nullable_to_non_nullable
              as List<Citation>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AskAnswerImplCopyWith<$Res>
    implements $AskAnswerCopyWith<$Res> {
  factory _$$AskAnswerImplCopyWith(
          _$AskAnswerImpl value, $Res Function(_$AskAnswerImpl) then) =
      __$$AskAnswerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String answer, String lang, List<Citation> citations});
}

/// @nodoc
class __$$AskAnswerImplCopyWithImpl<$Res>
    extends _$AskAnswerCopyWithImpl<$Res, _$AskAnswerImpl>
    implements _$$AskAnswerImplCopyWith<$Res> {
  __$$AskAnswerImplCopyWithImpl(
      _$AskAnswerImpl _value, $Res Function(_$AskAnswerImpl) _then)
      : super(_value, _then);

  /// Create a copy of AskAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? lang = null,
    Object? citations = null,
  }) {
    return _then(_$AskAnswerImpl(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      lang: null == lang
          ? _value.lang
          : lang // ignore: cast_nullable_to_non_nullable
              as String,
      citations: null == citations
          ? _value._citations
          : citations // ignore: cast_nullable_to_non_nullable
              as List<Citation>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AskAnswerImpl implements _AskAnswer {
  const _$AskAnswerImpl(
      {required this.answer,
      required this.lang,
      final List<Citation> citations = const []})
      : _citations = citations;

  factory _$AskAnswerImpl.fromJson(Map<String, dynamic> json) =>
      _$$AskAnswerImplFromJson(json);

  /// The answer prose, in the same language as the question.
  @override
  final String answer;

  /// "si" | "en".
  @override
  final String lang;

  /// Sources the answer is grounded on (may be empty).
  final List<Citation> _citations;

  /// Sources the answer is grounded on (may be empty).
  @override
  @JsonKey()
  List<Citation> get citations {
    if (_citations is EqualUnmodifiableListView) return _citations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_citations);
  }

  @override
  String toString() {
    return 'AskAnswer(answer: $answer, lang: $lang, citations: $citations)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AskAnswerImpl &&
            (identical(other.answer, answer) || other.answer == answer) &&
            (identical(other.lang, lang) || other.lang == lang) &&
            const DeepCollectionEquality()
                .equals(other._citations, _citations));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, answer, lang,
      const DeepCollectionEquality().hash(_citations));

  /// Create a copy of AskAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AskAnswerImplCopyWith<_$AskAnswerImpl> get copyWith =>
      __$$AskAnswerImplCopyWithImpl<_$AskAnswerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AskAnswerImplToJson(
      this,
    );
  }
}

abstract class _AskAnswer implements AskAnswer {
  const factory _AskAnswer(
      {required final String answer,
      required final String lang,
      final List<Citation> citations}) = _$AskAnswerImpl;

  factory _AskAnswer.fromJson(Map<String, dynamic> json) =
      _$AskAnswerImpl.fromJson;

  /// The answer prose, in the same language as the question.
  @override
  String get answer;

  /// "si" | "en".
  @override
  String get lang;

  /// Sources the answer is grounded on (may be empty).
  @override
  List<Citation> get citations;

  /// Create a copy of AskAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AskAnswerImplCopyWith<_$AskAnswerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
