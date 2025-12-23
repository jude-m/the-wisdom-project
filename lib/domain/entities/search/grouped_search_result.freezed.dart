// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grouped_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GroupedSearchResult {
  /// Results grouped by result type (limited preview, e.g., max 3 per result type)
  Map<SearchResultType, List<SearchResult>> get resultsByType =>
      throw _privateConstructorUsedError;

  /// Create a copy of GroupedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupedSearchResultCopyWith<GroupedSearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupedSearchResultCopyWith<$Res> {
  factory $GroupedSearchResultCopyWith(
          GroupedSearchResult value, $Res Function(GroupedSearchResult) then) =
      _$GroupedSearchResultCopyWithImpl<$Res, GroupedSearchResult>;
  @useResult
  $Res call({Map<SearchResultType, List<SearchResult>> resultsByType});
}

/// @nodoc
class _$GroupedSearchResultCopyWithImpl<$Res, $Val extends GroupedSearchResult>
    implements $GroupedSearchResultCopyWith<$Res> {
  _$GroupedSearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resultsByType = null,
  }) {
    return _then(_value.copyWith(
      resultsByType: null == resultsByType
          ? _value.resultsByType
          : resultsByType // ignore: cast_nullable_to_non_nullable
              as Map<SearchResultType, List<SearchResult>>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GroupedSearchResultImplCopyWith<$Res>
    implements $GroupedSearchResultCopyWith<$Res> {
  factory _$$GroupedSearchResultImplCopyWith(_$GroupedSearchResultImpl value,
          $Res Function(_$GroupedSearchResultImpl) then) =
      __$$GroupedSearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<SearchResultType, List<SearchResult>> resultsByType});
}

/// @nodoc
class __$$GroupedSearchResultImplCopyWithImpl<$Res>
    extends _$GroupedSearchResultCopyWithImpl<$Res, _$GroupedSearchResultImpl>
    implements _$$GroupedSearchResultImplCopyWith<$Res> {
  __$$GroupedSearchResultImplCopyWithImpl(_$GroupedSearchResultImpl _value,
      $Res Function(_$GroupedSearchResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of GroupedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resultsByType = null,
  }) {
    return _then(_$GroupedSearchResultImpl(
      resultsByType: null == resultsByType
          ? _value._resultsByType
          : resultsByType // ignore: cast_nullable_to_non_nullable
              as Map<SearchResultType, List<SearchResult>>,
    ));
  }
}

/// @nodoc

class _$GroupedSearchResultImpl extends _GroupedSearchResult {
  const _$GroupedSearchResultImpl(
      {required final Map<SearchResultType, List<SearchResult>> resultsByType})
      : _resultsByType = resultsByType,
        super._();

  /// Results grouped by result type (limited preview, e.g., max 3 per result type)
  final Map<SearchResultType, List<SearchResult>> _resultsByType;

  /// Results grouped by result type (limited preview, e.g., max 3 per result type)
  @override
  Map<SearchResultType, List<SearchResult>> get resultsByType {
    if (_resultsByType is EqualUnmodifiableMapView) return _resultsByType;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_resultsByType);
  }

  @override
  String toString() {
    return 'GroupedSearchResult(resultsByType: $resultsByType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupedSearchResultImpl &&
            const DeepCollectionEquality()
                .equals(other._resultsByType, _resultsByType));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_resultsByType));

  /// Create a copy of GroupedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupedSearchResultImplCopyWith<_$GroupedSearchResultImpl> get copyWith =>
      __$$GroupedSearchResultImplCopyWithImpl<_$GroupedSearchResultImpl>(
          this, _$identity);
}

abstract class _GroupedSearchResult extends GroupedSearchResult {
  const factory _GroupedSearchResult(
      {required final Map<SearchResultType, List<SearchResult>>
          resultsByType}) = _$GroupedSearchResultImpl;
  const _GroupedSearchResult._() : super._();

  /// Results grouped by result type (limited preview, e.g., max 3 per result type)
  @override
  Map<SearchResultType, List<SearchResult>> get resultsByType;

  /// Create a copy of GroupedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupedSearchResultImplCopyWith<_$GroupedSearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
