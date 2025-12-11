// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'categorized_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CategorizedSearchResult {
  /// Results grouped by category
  Map<SearchCategory, List<SearchResult>> get resultsByCategory =>
      throw _privateConstructorUsedError;

  /// Total count of all results across all categories
  int get totalCount => throw _privateConstructorUsedError;

  /// Create a copy of CategorizedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategorizedSearchResultCopyWith<CategorizedSearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategorizedSearchResultCopyWith<$Res> {
  factory $CategorizedSearchResultCopyWith(CategorizedSearchResult value,
          $Res Function(CategorizedSearchResult) then) =
      _$CategorizedSearchResultCopyWithImpl<$Res, CategorizedSearchResult>;
  @useResult
  $Res call(
      {Map<SearchCategory, List<SearchResult>> resultsByCategory,
      int totalCount});
}

/// @nodoc
class _$CategorizedSearchResultCopyWithImpl<$Res,
        $Val extends CategorizedSearchResult>
    implements $CategorizedSearchResultCopyWith<$Res> {
  _$CategorizedSearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategorizedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resultsByCategory = null,
    Object? totalCount = null,
  }) {
    return _then(_value.copyWith(
      resultsByCategory: null == resultsByCategory
          ? _value.resultsByCategory
          : resultsByCategory // ignore: cast_nullable_to_non_nullable
              as Map<SearchCategory, List<SearchResult>>,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CategorizedSearchResultImplCopyWith<$Res>
    implements $CategorizedSearchResultCopyWith<$Res> {
  factory _$$CategorizedSearchResultImplCopyWith(
          _$CategorizedSearchResultImpl value,
          $Res Function(_$CategorizedSearchResultImpl) then) =
      __$$CategorizedSearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<SearchCategory, List<SearchResult>> resultsByCategory,
      int totalCount});
}

/// @nodoc
class __$$CategorizedSearchResultImplCopyWithImpl<$Res>
    extends _$CategorizedSearchResultCopyWithImpl<$Res,
        _$CategorizedSearchResultImpl>
    implements _$$CategorizedSearchResultImplCopyWith<$Res> {
  __$$CategorizedSearchResultImplCopyWithImpl(
      _$CategorizedSearchResultImpl _value,
      $Res Function(_$CategorizedSearchResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of CategorizedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resultsByCategory = null,
    Object? totalCount = null,
  }) {
    return _then(_$CategorizedSearchResultImpl(
      resultsByCategory: null == resultsByCategory
          ? _value._resultsByCategory
          : resultsByCategory // ignore: cast_nullable_to_non_nullable
              as Map<SearchCategory, List<SearchResult>>,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$CategorizedSearchResultImpl extends _CategorizedSearchResult {
  const _$CategorizedSearchResultImpl(
      {required final Map<SearchCategory, List<SearchResult>> resultsByCategory,
      required this.totalCount})
      : _resultsByCategory = resultsByCategory,
        super._();

  /// Results grouped by category
  final Map<SearchCategory, List<SearchResult>> _resultsByCategory;

  /// Results grouped by category
  @override
  Map<SearchCategory, List<SearchResult>> get resultsByCategory {
    if (_resultsByCategory is EqualUnmodifiableMapView)
      return _resultsByCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_resultsByCategory);
  }

  /// Total count of all results across all categories
  @override
  final int totalCount;

  @override
  String toString() {
    return 'CategorizedSearchResult(resultsByCategory: $resultsByCategory, totalCount: $totalCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategorizedSearchResultImpl &&
            const DeepCollectionEquality()
                .equals(other._resultsByCategory, _resultsByCategory) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_resultsByCategory), totalCount);

  /// Create a copy of CategorizedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategorizedSearchResultImplCopyWith<_$CategorizedSearchResultImpl>
      get copyWith => __$$CategorizedSearchResultImplCopyWithImpl<
          _$CategorizedSearchResultImpl>(this, _$identity);
}

abstract class _CategorizedSearchResult extends CategorizedSearchResult {
  const factory _CategorizedSearchResult(
      {required final Map<SearchCategory, List<SearchResult>> resultsByCategory,
      required final int totalCount}) = _$CategorizedSearchResultImpl;
  const _CategorizedSearchResult._() : super._();

  /// Results grouped by category
  @override
  Map<SearchCategory, List<SearchResult>> get resultsByCategory;

  /// Total count of all results across all categories
  @override
  int get totalCount;

  /// Create a copy of CategorizedSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategorizedSearchResultImplCopyWith<_$CategorizedSearchResultImpl>
      get copyWith => throw _privateConstructorUsedError;
}
