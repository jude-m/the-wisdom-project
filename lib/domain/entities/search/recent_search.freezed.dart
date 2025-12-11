// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_search.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RecentSearch _$RecentSearchFromJson(Map<String, dynamic> json) {
  return _RecentSearch.fromJson(json);
}

/// @nodoc
mixin _$RecentSearch {
  /// The search query text
  String get queryText => throw _privateConstructorUsedError;

  /// When this search was performed
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this RecentSearch to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecentSearch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecentSearchCopyWith<RecentSearch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecentSearchCopyWith<$Res> {
  factory $RecentSearchCopyWith(
          RecentSearch value, $Res Function(RecentSearch) then) =
      _$RecentSearchCopyWithImpl<$Res, RecentSearch>;
  @useResult
  $Res call({String queryText, DateTime timestamp});
}

/// @nodoc
class _$RecentSearchCopyWithImpl<$Res, $Val extends RecentSearch>
    implements $RecentSearchCopyWith<$Res> {
  _$RecentSearchCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecentSearch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecentSearchImplCopyWith<$Res>
    implements $RecentSearchCopyWith<$Res> {
  factory _$$RecentSearchImplCopyWith(
          _$RecentSearchImpl value, $Res Function(_$RecentSearchImpl) then) =
      __$$RecentSearchImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String queryText, DateTime timestamp});
}

/// @nodoc
class __$$RecentSearchImplCopyWithImpl<$Res>
    extends _$RecentSearchCopyWithImpl<$Res, _$RecentSearchImpl>
    implements _$$RecentSearchImplCopyWith<$Res> {
  __$$RecentSearchImplCopyWithImpl(
      _$RecentSearchImpl _value, $Res Function(_$RecentSearchImpl) _then)
      : super(_value, _then);

  /// Create a copy of RecentSearch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? timestamp = null,
  }) {
    return _then(_$RecentSearchImpl(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecentSearchImpl implements _RecentSearch {
  const _$RecentSearchImpl({required this.queryText, required this.timestamp});

  factory _$RecentSearchImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecentSearchImplFromJson(json);

  /// The search query text
  @override
  final String queryText;

  /// When this search was performed
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'RecentSearch(queryText: $queryText, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecentSearchImpl &&
            (identical(other.queryText, queryText) ||
                other.queryText == queryText) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, queryText, timestamp);

  /// Create a copy of RecentSearch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecentSearchImplCopyWith<_$RecentSearchImpl> get copyWith =>
      __$$RecentSearchImplCopyWithImpl<_$RecentSearchImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecentSearchImplToJson(
      this,
    );
  }
}

abstract class _RecentSearch implements RecentSearch {
  const factory _RecentSearch(
      {required final String queryText,
      required final DateTime timestamp}) = _$RecentSearchImpl;

  factory _RecentSearch.fromJson(Map<String, dynamic> json) =
      _$RecentSearchImpl.fromJson;

  /// The search query text
  @override
  String get queryText;

  /// When this search was performed
  @override
  DateTime get timestamp;

  /// Create a copy of RecentSearch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecentSearchImplCopyWith<_$RecentSearchImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
