// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dictionary_params.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DictionaryLookupParams {
  /// The word to look up
  String get word => throw _privateConstructorUsedError;

  /// Whether to require exact match (no prefix matching)
  /// Default false = prefix matching enabled
  bool get exactMatch => throw _privateConstructorUsedError;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  String? get targetLanguage => throw _privateConstructorUsedError;

  /// Maximum number of results to return
  int get limit => throw _privateConstructorUsedError;

  /// Create a copy of DictionaryLookupParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DictionaryLookupParamsCopyWith<DictionaryLookupParams> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DictionaryLookupParamsCopyWith<$Res> {
  factory $DictionaryLookupParamsCopyWith(DictionaryLookupParams value,
          $Res Function(DictionaryLookupParams) then) =
      _$DictionaryLookupParamsCopyWithImpl<$Res, DictionaryLookupParams>;
  @useResult
  $Res call({String word, bool exactMatch, String? targetLanguage, int limit});
}

/// @nodoc
class _$DictionaryLookupParamsCopyWithImpl<$Res,
        $Val extends DictionaryLookupParams>
    implements $DictionaryLookupParamsCopyWith<$Res> {
  _$DictionaryLookupParamsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DictionaryLookupParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? exactMatch = null,
    Object? targetLanguage = freezed,
    Object? limit = null,
  }) {
    return _then(_value.copyWith(
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      exactMatch: null == exactMatch
          ? _value.exactMatch
          : exactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      targetLanguage: freezed == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DictionaryLookupParamsImplCopyWith<$Res>
    implements $DictionaryLookupParamsCopyWith<$Res> {
  factory _$$DictionaryLookupParamsImplCopyWith(
          _$DictionaryLookupParamsImpl value,
          $Res Function(_$DictionaryLookupParamsImpl) then) =
      __$$DictionaryLookupParamsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String word, bool exactMatch, String? targetLanguage, int limit});
}

/// @nodoc
class __$$DictionaryLookupParamsImplCopyWithImpl<$Res>
    extends _$DictionaryLookupParamsCopyWithImpl<$Res,
        _$DictionaryLookupParamsImpl>
    implements _$$DictionaryLookupParamsImplCopyWith<$Res> {
  __$$DictionaryLookupParamsImplCopyWithImpl(
      _$DictionaryLookupParamsImpl _value,
      $Res Function(_$DictionaryLookupParamsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DictionaryLookupParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? exactMatch = null,
    Object? targetLanguage = freezed,
    Object? limit = null,
  }) {
    return _then(_$DictionaryLookupParamsImpl(
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      exactMatch: null == exactMatch
          ? _value.exactMatch
          : exactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      targetLanguage: freezed == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$DictionaryLookupParamsImpl implements _DictionaryLookupParams {
  const _$DictionaryLookupParamsImpl(
      {required this.word,
      this.exactMatch = false,
      this.targetLanguage,
      this.limit = 50});

  /// The word to look up
  @override
  final String word;

  /// Whether to require exact match (no prefix matching)
  /// Default false = prefix matching enabled
  @override
  @JsonKey()
  final bool exactMatch;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  @override
  final String? targetLanguage;

  /// Maximum number of results to return
  @override
  @JsonKey()
  final int limit;

  @override
  String toString() {
    return 'DictionaryLookupParams(word: $word, exactMatch: $exactMatch, targetLanguage: $targetLanguage, limit: $limit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DictionaryLookupParamsImpl &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.exactMatch, exactMatch) ||
                other.exactMatch == exactMatch) &&
            (identical(other.targetLanguage, targetLanguage) ||
                other.targetLanguage == targetLanguage) &&
            (identical(other.limit, limit) || other.limit == limit));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, word, exactMatch, targetLanguage, limit);

  /// Create a copy of DictionaryLookupParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DictionaryLookupParamsImplCopyWith<_$DictionaryLookupParamsImpl>
      get copyWith => __$$DictionaryLookupParamsImplCopyWithImpl<
          _$DictionaryLookupParamsImpl>(this, _$identity);
}

abstract class _DictionaryLookupParams implements DictionaryLookupParams {
  const factory _DictionaryLookupParams(
      {required final String word,
      final bool exactMatch,
      final String? targetLanguage,
      final int limit}) = _$DictionaryLookupParamsImpl;

  /// The word to look up
  @override
  String get word;

  /// Whether to require exact match (no prefix matching)
  /// Default false = prefix matching enabled
  @override
  bool get exactMatch;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  @override
  String? get targetLanguage;

  /// Maximum number of results to return
  @override
  int get limit;

  /// Create a copy of DictionaryLookupParams
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DictionaryLookupParamsImplCopyWith<_$DictionaryLookupParamsImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DictionarySearchParams {
  /// The search query text
  String get query => throw _privateConstructorUsedError;

  /// Whether to require exact word match (no prefix matching)
  bool get isExactMatch => throw _privateConstructorUsedError;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  String? get targetLanguage => throw _privateConstructorUsedError;

  /// Maximum number of results to return
  int get limit => throw _privateConstructorUsedError;

  /// Create a copy of DictionarySearchParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DictionarySearchParamsCopyWith<DictionarySearchParams> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DictionarySearchParamsCopyWith<$Res> {
  factory $DictionarySearchParamsCopyWith(DictionarySearchParams value,
          $Res Function(DictionarySearchParams) then) =
      _$DictionarySearchParamsCopyWithImpl<$Res, DictionarySearchParams>;
  @useResult
  $Res call(
      {String query, bool isExactMatch, String? targetLanguage, int limit});
}

/// @nodoc
class _$DictionarySearchParamsCopyWithImpl<$Res,
        $Val extends DictionarySearchParams>
    implements $DictionarySearchParamsCopyWith<$Res> {
  _$DictionarySearchParamsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DictionarySearchParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? isExactMatch = null,
    Object? targetLanguage = freezed,
    Object? limit = null,
  }) {
    return _then(_value.copyWith(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      targetLanguage: freezed == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DictionarySearchParamsImplCopyWith<$Res>
    implements $DictionarySearchParamsCopyWith<$Res> {
  factory _$$DictionarySearchParamsImplCopyWith(
          _$DictionarySearchParamsImpl value,
          $Res Function(_$DictionarySearchParamsImpl) then) =
      __$$DictionarySearchParamsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String query, bool isExactMatch, String? targetLanguage, int limit});
}

/// @nodoc
class __$$DictionarySearchParamsImplCopyWithImpl<$Res>
    extends _$DictionarySearchParamsCopyWithImpl<$Res,
        _$DictionarySearchParamsImpl>
    implements _$$DictionarySearchParamsImplCopyWith<$Res> {
  __$$DictionarySearchParamsImplCopyWithImpl(
      _$DictionarySearchParamsImpl _value,
      $Res Function(_$DictionarySearchParamsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DictionarySearchParams
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = null,
    Object? isExactMatch = null,
    Object? targetLanguage = freezed,
    Object? limit = null,
  }) {
    return _then(_$DictionarySearchParamsImpl(
      query: null == query
          ? _value.query
          : query // ignore: cast_nullable_to_non_nullable
              as String,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      targetLanguage: freezed == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$DictionarySearchParamsImpl implements _DictionarySearchParams {
  const _$DictionarySearchParamsImpl(
      {required this.query,
      this.isExactMatch = false,
      this.targetLanguage,
      this.limit = 50});

  /// The search query text
  @override
  final String query;

  /// Whether to require exact word match (no prefix matching)
  @override
  @JsonKey()
  final bool isExactMatch;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  @override
  final String? targetLanguage;

  /// Maximum number of results to return
  @override
  @JsonKey()
  final int limit;

  @override
  String toString() {
    return 'DictionarySearchParams(query: $query, isExactMatch: $isExactMatch, targetLanguage: $targetLanguage, limit: $limit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DictionarySearchParamsImpl &&
            (identical(other.query, query) || other.query == query) &&
            (identical(other.isExactMatch, isExactMatch) ||
                other.isExactMatch == isExactMatch) &&
            (identical(other.targetLanguage, targetLanguage) ||
                other.targetLanguage == targetLanguage) &&
            (identical(other.limit, limit) || other.limit == limit));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, query, isExactMatch, targetLanguage, limit);

  /// Create a copy of DictionarySearchParams
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DictionarySearchParamsImplCopyWith<_$DictionarySearchParamsImpl>
      get copyWith => __$$DictionarySearchParamsImplCopyWithImpl<
          _$DictionarySearchParamsImpl>(this, _$identity);
}

abstract class _DictionarySearchParams implements DictionarySearchParams {
  const factory _DictionarySearchParams(
      {required final String query,
      final bool isExactMatch,
      final String? targetLanguage,
      final int limit}) = _$DictionarySearchParamsImpl;

  /// The search query text
  @override
  String get query;

  /// Whether to require exact word match (no prefix matching)
  @override
  bool get isExactMatch;

  /// Filter by target language ('en'/'si')
  /// Default null = all languages
  @override
  String? get targetLanguage;

  /// Maximum number of results to return
  @override
  int get limit;

  /// Create a copy of DictionarySearchParams
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DictionarySearchParamsImplCopyWith<_$DictionarySearchParamsImpl>
      get copyWith => throw _privateConstructorUsedError;
}
