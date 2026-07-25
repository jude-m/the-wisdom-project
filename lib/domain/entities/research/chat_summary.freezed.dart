// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatSummary _$ChatSummaryFromJson(Map<String, dynamic> json) {
  return _ChatSummary.fromJson(json);
}

/// @nodoc
mixin _$ChatSummary {
  /// Stable id — also the suffix of the transcript's storage key.
  String get id => throw _privateConstructorUsedError;

  /// Display title: the chat's first user question (ellipsized by the UI).
  String get title => throw _privateConstructorUsedError;

  /// Last activity — drives newest-first ordering and the relative
  /// timestamp ("2 hours ago") in the list.
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// The Fast/Thinking tier this chat last sent a question under, so
  /// reopening it restores the same tier (a chat is remembered per-tier,
  /// unlike the "always Fast" new-chat default). Defaults to
  /// [ResearchMode.fast], which also covers chats saved before this field
  /// existed (the key is simply absent → Fast on read).
  ResearchMode get mode => throw _privateConstructorUsedError;

  /// Serializes this ChatSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatSummaryCopyWith<ChatSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatSummaryCopyWith<$Res> {
  factory $ChatSummaryCopyWith(
          ChatSummary value, $Res Function(ChatSummary) then) =
      _$ChatSummaryCopyWithImpl<$Res, ChatSummary>;
  @useResult
  $Res call({String id, String title, DateTime updatedAt, ResearchMode mode});
}

/// @nodoc
class _$ChatSummaryCopyWithImpl<$Res, $Val extends ChatSummary>
    implements $ChatSummaryCopyWith<$Res> {
  _$ChatSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? updatedAt = null,
    Object? mode = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as ResearchMode,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatSummaryImplCopyWith<$Res>
    implements $ChatSummaryCopyWith<$Res> {
  factory _$$ChatSummaryImplCopyWith(
          _$ChatSummaryImpl value, $Res Function(_$ChatSummaryImpl) then) =
      __$$ChatSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, DateTime updatedAt, ResearchMode mode});
}

/// @nodoc
class __$$ChatSummaryImplCopyWithImpl<$Res>
    extends _$ChatSummaryCopyWithImpl<$Res, _$ChatSummaryImpl>
    implements _$$ChatSummaryImplCopyWith<$Res> {
  __$$ChatSummaryImplCopyWithImpl(
      _$ChatSummaryImpl _value, $Res Function(_$ChatSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? updatedAt = null,
    Object? mode = null,
  }) {
    return _then(_$ChatSummaryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as ResearchMode,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatSummaryImpl implements _ChatSummary {
  const _$ChatSummaryImpl(
      {required this.id,
      required this.title,
      required this.updatedAt,
      this.mode = ResearchMode.fast});

  factory _$ChatSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatSummaryImplFromJson(json);

  /// Stable id — also the suffix of the transcript's storage key.
  @override
  final String id;

  /// Display title: the chat's first user question (ellipsized by the UI).
  @override
  final String title;

  /// Last activity — drives newest-first ordering and the relative
  /// timestamp ("2 hours ago") in the list.
  @override
  final DateTime updatedAt;

  /// The Fast/Thinking tier this chat last sent a question under, so
  /// reopening it restores the same tier (a chat is remembered per-tier,
  /// unlike the "always Fast" new-chat default). Defaults to
  /// [ResearchMode.fast], which also covers chats saved before this field
  /// existed (the key is simply absent → Fast on read).
  @override
  @JsonKey()
  final ResearchMode mode;

  @override
  String toString() {
    return 'ChatSummary(id: $id, title: $title, updatedAt: $updatedAt, mode: $mode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.mode, mode) || other.mode == mode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, updatedAt, mode);

  /// Create a copy of ChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatSummaryImplCopyWith<_$ChatSummaryImpl> get copyWith =>
      __$$ChatSummaryImplCopyWithImpl<_$ChatSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatSummaryImplToJson(
      this,
    );
  }
}

abstract class _ChatSummary implements ChatSummary {
  const factory _ChatSummary(
      {required final String id,
      required final String title,
      required final DateTime updatedAt,
      final ResearchMode mode}) = _$ChatSummaryImpl;

  factory _ChatSummary.fromJson(Map<String, dynamic> json) =
      _$ChatSummaryImpl.fromJson;

  /// Stable id — also the suffix of the transcript's storage key.
  @override
  String get id;

  /// Display title: the chat's first user question (ellipsized by the UI).
  @override
  String get title;

  /// Last activity — drives newest-first ordering and the relative
  /// timestamp ("2 hours ago") in the list.
  @override
  DateTime get updatedAt;

  /// The Fast/Thinking tier this chat last sent a question under, so
  /// reopening it restores the same tier (a chat is remembered per-tier,
  /// unlike the "always Fast" new-chat default). Defaults to
  /// [ResearchMode.fast], which also covers chats saved before this field
  /// existed (the key is simply absent → Fast on read).
  @override
  ResearchMode get mode;

  /// Create a copy of ChatSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatSummaryImplCopyWith<_$ChatSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
