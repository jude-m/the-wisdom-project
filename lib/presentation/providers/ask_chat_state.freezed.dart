// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ask_chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AskChatState {
  /// Full transcript, oldest first. Assistant turns carry their citations.
  List<ChatMessage> get messages => throw _privateConstructorUsedError;

  /// True while a question is in flight — disables the send button (a real
  /// client-side cost guardrail) and shows a "thinking…" row.
  bool get isLoading => throw _privateConstructorUsedError;

  /// User-facing error from the last attempt, or null.
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of AskChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AskChatStateCopyWith<AskChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AskChatStateCopyWith<$Res> {
  factory $AskChatStateCopyWith(
          AskChatState value, $Res Function(AskChatState) then) =
      _$AskChatStateCopyWithImpl<$Res, AskChatState>;
  @useResult
  $Res call({List<ChatMessage> messages, bool isLoading, String? error});
}

/// @nodoc
class _$AskChatStateCopyWithImpl<$Res, $Val extends AskChatState>
    implements $AskChatStateCopyWith<$Res> {
  _$AskChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AskChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AskChatStateImplCopyWith<$Res>
    implements $AskChatStateCopyWith<$Res> {
  factory _$$AskChatStateImplCopyWith(
          _$AskChatStateImpl value, $Res Function(_$AskChatStateImpl) then) =
      __$$AskChatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<ChatMessage> messages, bool isLoading, String? error});
}

/// @nodoc
class __$$AskChatStateImplCopyWithImpl<$Res>
    extends _$AskChatStateCopyWithImpl<$Res, _$AskChatStateImpl>
    implements _$$AskChatStateImplCopyWith<$Res> {
  __$$AskChatStateImplCopyWithImpl(
      _$AskChatStateImpl _value, $Res Function(_$AskChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AskChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messages = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_$AskChatStateImpl(
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$AskChatStateImpl implements _AskChatState {
  const _$AskChatStateImpl(
      {final List<ChatMessage> messages = const [],
      this.isLoading = false,
      this.error})
      : _messages = messages;

  /// Full transcript, oldest first. Assistant turns carry their citations.
  final List<ChatMessage> _messages;

  /// Full transcript, oldest first. Assistant turns carry their citations.
  @override
  @JsonKey()
  List<ChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  /// True while a question is in flight — disables the send button (a real
  /// client-side cost guardrail) and shows a "thinking…" row.
  @override
  @JsonKey()
  final bool isLoading;

  /// User-facing error from the last attempt, or null.
  @override
  final String? error;

  @override
  String toString() {
    return 'AskChatState(messages: $messages, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AskChatStateImpl &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_messages), isLoading, error);

  /// Create a copy of AskChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AskChatStateImplCopyWith<_$AskChatStateImpl> get copyWith =>
      __$$AskChatStateImplCopyWithImpl<_$AskChatStateImpl>(this, _$identity);
}

abstract class _AskChatState implements AskChatState {
  const factory _AskChatState(
      {final List<ChatMessage> messages,
      final bool isLoading,
      final String? error}) = _$AskChatStateImpl;

  /// Full transcript, oldest first. Assistant turns carry their citations.
  @override
  List<ChatMessage> get messages;

  /// True while a question is in flight — disables the send button (a real
  /// client-side cost guardrail) and shows a "thinking…" row.
  @override
  bool get isLoading;

  /// User-facing error from the last attempt, or null.
  @override
  String? get error;

  /// Create a copy of AskChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AskChatStateImplCopyWith<_$AskChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
