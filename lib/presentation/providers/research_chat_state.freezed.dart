// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'research_chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ResearchChatState {
  /// Id of the saved chat this transcript belongs to, or null for a fresh
  /// chat that hasn't sent its first message yet (unsent chats are never
  /// persisted, so "New chat" spam can't pollute the Recent list).
  String? get sessionId => throw _privateConstructorUsedError;

  /// Full transcript, oldest first. Assistant turns carry their citations.
  List<ChatMessage> get messages => throw _privateConstructorUsedError;

  /// True while a question is in flight — disables the send button (a real
  /// client-side cost guardrail) and shows the busy row.
  bool get isLoading => throw _privateConstructorUsedError;

  /// The Fast/Thinking mode the in-flight request is running under, pinned at
  /// send time. The busy row's label ("Answering…" / "Thinking…") reads THIS,
  /// not the live global mode, so flipping the switch mid-request can't
  /// relabel the answer already running (mirrors how send() pins the mode it
  /// sends to the backend). Only meaningful while [isLoading]; not persisted —
  /// openChat restores it from the pending-session map, defaulting to fast.
  ResearchMode get inFlightMode => throw _privateConstructorUsedError;

  /// User-facing error message from the last attempt, or null. Kept as an
  /// English fallback / for logging; the chat view prefers [errorType] and
  /// re-localises by category (see research_error_messages.dart).
  String? get error => throw _privateConstructorUsedError;

  /// Category of the last error, or null. Drives the localised message and
  /// whether the chat view offers a Retry (see [ApiErrorType]).
  ApiErrorType? get errorType => throw _privateConstructorUsedError;

  /// Create a copy of ResearchChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ResearchChatStateCopyWith<ResearchChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResearchChatStateCopyWith<$Res> {
  factory $ResearchChatStateCopyWith(
          ResearchChatState value, $Res Function(ResearchChatState) then) =
      _$ResearchChatStateCopyWithImpl<$Res, ResearchChatState>;
  @useResult
  $Res call(
      {String? sessionId,
      List<ChatMessage> messages,
      bool isLoading,
      ResearchMode inFlightMode,
      String? error,
      ApiErrorType? errorType});
}

/// @nodoc
class _$ResearchChatStateCopyWithImpl<$Res, $Val extends ResearchChatState>
    implements $ResearchChatStateCopyWith<$Res> {
  _$ResearchChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ResearchChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = freezed,
    Object? messages = null,
    Object? isLoading = null,
    Object? inFlightMode = null,
    Object? error = freezed,
    Object? errorType = freezed,
  }) {
    return _then(_value.copyWith(
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      inFlightMode: null == inFlightMode
          ? _value.inFlightMode
          : inFlightMode // ignore: cast_nullable_to_non_nullable
              as ResearchMode,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      errorType: freezed == errorType
          ? _value.errorType
          : errorType // ignore: cast_nullable_to_non_nullable
              as ApiErrorType?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ResearchChatStateImplCopyWith<$Res>
    implements $ResearchChatStateCopyWith<$Res> {
  factory _$$ResearchChatStateImplCopyWith(_$ResearchChatStateImpl value,
          $Res Function(_$ResearchChatStateImpl) then) =
      __$$ResearchChatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? sessionId,
      List<ChatMessage> messages,
      bool isLoading,
      ResearchMode inFlightMode,
      String? error,
      ApiErrorType? errorType});
}

/// @nodoc
class __$$ResearchChatStateImplCopyWithImpl<$Res>
    extends _$ResearchChatStateCopyWithImpl<$Res, _$ResearchChatStateImpl>
    implements _$$ResearchChatStateImplCopyWith<$Res> {
  __$$ResearchChatStateImplCopyWithImpl(_$ResearchChatStateImpl _value,
      $Res Function(_$ResearchChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ResearchChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = freezed,
    Object? messages = null,
    Object? isLoading = null,
    Object? inFlightMode = null,
    Object? error = freezed,
    Object? errorType = freezed,
  }) {
    return _then(_$ResearchChatStateImpl(
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      inFlightMode: null == inFlightMode
          ? _value.inFlightMode
          : inFlightMode // ignore: cast_nullable_to_non_nullable
              as ResearchMode,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      errorType: freezed == errorType
          ? _value.errorType
          : errorType // ignore: cast_nullable_to_non_nullable
              as ApiErrorType?,
    ));
  }
}

/// @nodoc

class _$ResearchChatStateImpl extends _ResearchChatState {
  const _$ResearchChatStateImpl(
      {this.sessionId,
      final List<ChatMessage> messages = const [],
      this.isLoading = false,
      this.inFlightMode = ResearchMode.fast,
      this.error,
      this.errorType})
      : _messages = messages,
        super._();

  /// Id of the saved chat this transcript belongs to, or null for a fresh
  /// chat that hasn't sent its first message yet (unsent chats are never
  /// persisted, so "New chat" spam can't pollute the Recent list).
  @override
  final String? sessionId;

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
  /// client-side cost guardrail) and shows the busy row.
  @override
  @JsonKey()
  final bool isLoading;

  /// The Fast/Thinking mode the in-flight request is running under, pinned at
  /// send time. The busy row's label ("Answering…" / "Thinking…") reads THIS,
  /// not the live global mode, so flipping the switch mid-request can't
  /// relabel the answer already running (mirrors how send() pins the mode it
  /// sends to the backend). Only meaningful while [isLoading]; not persisted —
  /// openChat restores it from the pending-session map, defaulting to fast.
  @override
  @JsonKey()
  final ResearchMode inFlightMode;

  /// User-facing error message from the last attempt, or null. Kept as an
  /// English fallback / for logging; the chat view prefers [errorType] and
  /// re-localises by category (see research_error_messages.dart).
  @override
  final String? error;

  /// Category of the last error, or null. Drives the localised message and
  /// whether the chat view offers a Retry (see [ApiErrorType]).
  @override
  final ApiErrorType? errorType;

  @override
  String toString() {
    return 'ResearchChatState(sessionId: $sessionId, messages: $messages, isLoading: $isLoading, inFlightMode: $inFlightMode, error: $error, errorType: $errorType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ResearchChatStateImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.inFlightMode, inFlightMode) ||
                other.inFlightMode == inFlightMode) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.errorType, errorType) ||
                other.errorType == errorType));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      sessionId,
      const DeepCollectionEquality().hash(_messages),
      isLoading,
      inFlightMode,
      error,
      errorType);

  /// Create a copy of ResearchChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ResearchChatStateImplCopyWith<_$ResearchChatStateImpl> get copyWith =>
      __$$ResearchChatStateImplCopyWithImpl<_$ResearchChatStateImpl>(
          this, _$identity);
}

abstract class _ResearchChatState extends ResearchChatState {
  const factory _ResearchChatState(
      {final String? sessionId,
      final List<ChatMessage> messages,
      final bool isLoading,
      final ResearchMode inFlightMode,
      final String? error,
      final ApiErrorType? errorType}) = _$ResearchChatStateImpl;
  const _ResearchChatState._() : super._();

  /// Id of the saved chat this transcript belongs to, or null for a fresh
  /// chat that hasn't sent its first message yet (unsent chats are never
  /// persisted, so "New chat" spam can't pollute the Recent list).
  @override
  String? get sessionId;

  /// Full transcript, oldest first. Assistant turns carry their citations.
  @override
  List<ChatMessage> get messages;

  /// True while a question is in flight — disables the send button (a real
  /// client-side cost guardrail) and shows the busy row.
  @override
  bool get isLoading;

  /// The Fast/Thinking mode the in-flight request is running under, pinned at
  /// send time. The busy row's label ("Answering…" / "Thinking…") reads THIS,
  /// not the live global mode, so flipping the switch mid-request can't
  /// relabel the answer already running (mirrors how send() pins the mode it
  /// sends to the backend). Only meaningful while [isLoading]; not persisted —
  /// openChat restores it from the pending-session map, defaulting to fast.
  @override
  ResearchMode get inFlightMode;

  /// User-facing error message from the last attempt, or null. Kept as an
  /// English fallback / for logging; the chat view prefers [errorType] and
  /// re-localises by category (see research_error_messages.dart).
  @override
  String? get error;

  /// Category of the last error, or null. Drives the localised message and
  /// whether the chat view offers a Retry (see [ApiErrorType]).
  @override
  ApiErrorType? get errorType;

  /// Create a copy of ResearchChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ResearchChatStateImplCopyWith<_$ResearchChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
