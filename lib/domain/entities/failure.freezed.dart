// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Failure {
  String get message => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FailureCopyWith<Failure> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FailureCopyWith<$Res> {
  factory $FailureCopyWith(Failure value, $Res Function(Failure) then) =
      _$FailureCopyWithImpl<$Res, Failure>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class _$FailureCopyWithImpl<$Res, $Val extends Failure>
    implements $FailureCopyWith<$Res> {
  _$FailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_value.copyWith(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DataLoadFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$DataLoadFailureImplCopyWith(_$DataLoadFailureImpl value,
          $Res Function(_$DataLoadFailureImpl) then) =
      __$$DataLoadFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message, Object? error});
}

/// @nodoc
class __$$DataLoadFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$DataLoadFailureImpl>
    implements _$$DataLoadFailureImplCopyWith<$Res> {
  __$$DataLoadFailureImplCopyWithImpl(
      _$DataLoadFailureImpl _value, $Res Function(_$DataLoadFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? error = freezed,
  }) {
    return _then(_$DataLoadFailureImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      error: freezed == error ? _value.error : error,
    ));
  }
}

/// @nodoc

class _$DataLoadFailureImpl extends DataLoadFailure {
  const _$DataLoadFailureImpl({required this.message, this.error}) : super._();

  @override
  final String message;
  @override
  final Object? error;

  @override
  String toString() {
    return 'Failure.dataLoadFailure(message: $message, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DataLoadFailureImpl &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, message, const DeepCollectionEquality().hash(error));

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DataLoadFailureImplCopyWith<_$DataLoadFailureImpl> get copyWith =>
      __$$DataLoadFailureImplCopyWithImpl<_$DataLoadFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) {
    return dataLoadFailure(message, error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) {
    return dataLoadFailure?.call(message, error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (dataLoadFailure != null) {
      return dataLoadFailure(message, error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) {
    return dataLoadFailure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) {
    return dataLoadFailure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (dataLoadFailure != null) {
      return dataLoadFailure(this);
    }
    return orElse();
  }
}

abstract class DataLoadFailure extends Failure {
  const factory DataLoadFailure(
      {required final String message,
      final Object? error}) = _$DataLoadFailureImpl;
  const DataLoadFailure._() : super._();

  @override
  String get message;
  Object? get error;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DataLoadFailureImplCopyWith<_$DataLoadFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DataParseFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$DataParseFailureImplCopyWith(_$DataParseFailureImpl value,
          $Res Function(_$DataParseFailureImpl) then) =
      __$$DataParseFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message, Object? error});
}

/// @nodoc
class __$$DataParseFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$DataParseFailureImpl>
    implements _$$DataParseFailureImplCopyWith<$Res> {
  __$$DataParseFailureImplCopyWithImpl(_$DataParseFailureImpl _value,
      $Res Function(_$DataParseFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? error = freezed,
  }) {
    return _then(_$DataParseFailureImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      error: freezed == error ? _value.error : error,
    ));
  }
}

/// @nodoc

class _$DataParseFailureImpl extends DataParseFailure {
  const _$DataParseFailureImpl({required this.message, this.error}) : super._();

  @override
  final String message;
  @override
  final Object? error;

  @override
  String toString() {
    return 'Failure.dataParseFailure(message: $message, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DataParseFailureImpl &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, message, const DeepCollectionEquality().hash(error));

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DataParseFailureImplCopyWith<_$DataParseFailureImpl> get copyWith =>
      __$$DataParseFailureImplCopyWithImpl<_$DataParseFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) {
    return dataParseFailure(message, error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) {
    return dataParseFailure?.call(message, error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (dataParseFailure != null) {
      return dataParseFailure(message, error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) {
    return dataParseFailure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) {
    return dataParseFailure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (dataParseFailure != null) {
      return dataParseFailure(this);
    }
    return orElse();
  }
}

abstract class DataParseFailure extends Failure {
  const factory DataParseFailure(
      {required final String message,
      final Object? error}) = _$DataParseFailureImpl;
  const DataParseFailure._() : super._();

  @override
  String get message;
  Object? get error;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DataParseFailureImplCopyWith<_$DataParseFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NotFoundFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$NotFoundFailureImplCopyWith(_$NotFoundFailureImpl value,
          $Res Function(_$NotFoundFailureImpl) then) =
      __$$NotFoundFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$NotFoundFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$NotFoundFailureImpl>
    implements _$$NotFoundFailureImplCopyWith<$Res> {
  __$$NotFoundFailureImplCopyWithImpl(
      _$NotFoundFailureImpl _value, $Res Function(_$NotFoundFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$NotFoundFailureImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$NotFoundFailureImpl extends NotFoundFailure {
  const _$NotFoundFailureImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'Failure.notFoundFailure(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotFoundFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotFoundFailureImplCopyWith<_$NotFoundFailureImpl> get copyWith =>
      __$$NotFoundFailureImplCopyWithImpl<_$NotFoundFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) {
    return notFoundFailure(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) {
    return notFoundFailure?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (notFoundFailure != null) {
      return notFoundFailure(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) {
    return notFoundFailure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) {
    return notFoundFailure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (notFoundFailure != null) {
      return notFoundFailure(this);
    }
    return orElse();
  }
}

abstract class NotFoundFailure extends Failure {
  const factory NotFoundFailure({required final String message}) =
      _$NotFoundFailureImpl;
  const NotFoundFailure._() : super._();

  @override
  String get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotFoundFailureImplCopyWith<_$NotFoundFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InvalidOperationFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$InvalidOperationFailureImplCopyWith(
          _$InvalidOperationFailureImpl value,
          $Res Function(_$InvalidOperationFailureImpl) then) =
      __$$InvalidOperationFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$InvalidOperationFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$InvalidOperationFailureImpl>
    implements _$$InvalidOperationFailureImplCopyWith<$Res> {
  __$$InvalidOperationFailureImplCopyWithImpl(
      _$InvalidOperationFailureImpl _value,
      $Res Function(_$InvalidOperationFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$InvalidOperationFailureImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$InvalidOperationFailureImpl extends InvalidOperationFailure {
  const _$InvalidOperationFailureImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'Failure.invalidOperationFailure(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvalidOperationFailureImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InvalidOperationFailureImplCopyWith<_$InvalidOperationFailureImpl>
      get copyWith => __$$InvalidOperationFailureImplCopyWithImpl<
          _$InvalidOperationFailureImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) {
    return invalidOperationFailure(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) {
    return invalidOperationFailure?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (invalidOperationFailure != null) {
      return invalidOperationFailure(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) {
    return invalidOperationFailure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) {
    return invalidOperationFailure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (invalidOperationFailure != null) {
      return invalidOperationFailure(this);
    }
    return orElse();
  }
}

abstract class InvalidOperationFailure extends Failure {
  const factory InvalidOperationFailure({required final String message}) =
      _$InvalidOperationFailureImpl;
  const InvalidOperationFailure._() : super._();

  @override
  String get message;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InvalidOperationFailureImplCopyWith<_$InvalidOperationFailureImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UnexpectedFailureImplCopyWith<$Res>
    implements $FailureCopyWith<$Res> {
  factory _$$UnexpectedFailureImplCopyWith(_$UnexpectedFailureImpl value,
          $Res Function(_$UnexpectedFailureImpl) then) =
      __$$UnexpectedFailureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message, Object? error});
}

/// @nodoc
class __$$UnexpectedFailureImplCopyWithImpl<$Res>
    extends _$FailureCopyWithImpl<$Res, _$UnexpectedFailureImpl>
    implements _$$UnexpectedFailureImplCopyWith<$Res> {
  __$$UnexpectedFailureImplCopyWithImpl(_$UnexpectedFailureImpl _value,
      $Res Function(_$UnexpectedFailureImpl) _then)
      : super(_value, _then);

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? error = freezed,
  }) {
    return _then(_$UnexpectedFailureImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      error: freezed == error ? _value.error : error,
    ));
  }
}

/// @nodoc

class _$UnexpectedFailureImpl extends UnexpectedFailure {
  const _$UnexpectedFailureImpl({required this.message, this.error})
      : super._();

  @override
  final String message;
  @override
  final Object? error;

  @override
  String toString() {
    return 'Failure.unexpectedFailure(message: $message, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnexpectedFailureImpl &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, message, const DeepCollectionEquality().hash(error));

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnexpectedFailureImplCopyWith<_$UnexpectedFailureImpl> get copyWith =>
      __$$UnexpectedFailureImplCopyWithImpl<_$UnexpectedFailureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message, Object? error) dataLoadFailure,
    required TResult Function(String message, Object? error) dataParseFailure,
    required TResult Function(String message) notFoundFailure,
    required TResult Function(String message) invalidOperationFailure,
    required TResult Function(String message, Object? error) unexpectedFailure,
  }) {
    return unexpectedFailure(message, error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message, Object? error)? dataLoadFailure,
    TResult? Function(String message, Object? error)? dataParseFailure,
    TResult? Function(String message)? notFoundFailure,
    TResult? Function(String message)? invalidOperationFailure,
    TResult? Function(String message, Object? error)? unexpectedFailure,
  }) {
    return unexpectedFailure?.call(message, error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message, Object? error)? dataLoadFailure,
    TResult Function(String message, Object? error)? dataParseFailure,
    TResult Function(String message)? notFoundFailure,
    TResult Function(String message)? invalidOperationFailure,
    TResult Function(String message, Object? error)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (unexpectedFailure != null) {
      return unexpectedFailure(message, error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(DataLoadFailure value) dataLoadFailure,
    required TResult Function(DataParseFailure value) dataParseFailure,
    required TResult Function(NotFoundFailure value) notFoundFailure,
    required TResult Function(InvalidOperationFailure value)
        invalidOperationFailure,
    required TResult Function(UnexpectedFailure value) unexpectedFailure,
  }) {
    return unexpectedFailure(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(DataLoadFailure value)? dataLoadFailure,
    TResult? Function(DataParseFailure value)? dataParseFailure,
    TResult? Function(NotFoundFailure value)? notFoundFailure,
    TResult? Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult? Function(UnexpectedFailure value)? unexpectedFailure,
  }) {
    return unexpectedFailure?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(DataLoadFailure value)? dataLoadFailure,
    TResult Function(DataParseFailure value)? dataParseFailure,
    TResult Function(NotFoundFailure value)? notFoundFailure,
    TResult Function(InvalidOperationFailure value)? invalidOperationFailure,
    TResult Function(UnexpectedFailure value)? unexpectedFailure,
    required TResult orElse(),
  }) {
    if (unexpectedFailure != null) {
      return unexpectedFailure(this);
    }
    return orElse();
  }
}

abstract class UnexpectedFailure extends Failure {
  const factory UnexpectedFailure(
      {required final String message,
      final Object? error}) = _$UnexpectedFailureImpl;
  const UnexpectedFailure._() : super._();

  @override
  String get message;
  Object? get error;

  /// Create a copy of Failure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnexpectedFailureImplCopyWith<_$UnexpectedFailureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
