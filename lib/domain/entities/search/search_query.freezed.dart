// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_query.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SearchQuery {
  /// The search query text
  String get queryText => throw _privateConstructorUsedError;

  /// Whether to require exact word match (no prefix matching)
  /// Default false = prefix matching enabled (e.g., "සති" matches "සතිපට්ඨානය")
  bool get isExactMatch => throw _privateConstructorUsedError;

  /// Editions to search within (e.g., {'bjt', 'sc'})
  /// If empty, searches all available editions
  Set<String> get editionIds => throw _privateConstructorUsedError;

  /// Whether to search in Pali text
  bool get searchInPali => throw _privateConstructorUsedError;

  /// Whether to search in Sinhala text
  bool get searchInSinhala => throw _privateConstructorUsedError;

  /// Selected scope to search within.
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Example:
  /// - {} = search everything
  /// - {sutta} = search only Sutta Pitaka
  /// - {sutta, commentaries} = search Sutta Pitaka OR Commentaries
  Set<SearchScope> get scope => throw _privateConstructorUsedError;

  /// Maximum number of results to return
  int get limit => throw _privateConstructorUsedError;

  /// Offset for pagination
  int get offset => throw _privateConstructorUsedError;

  /// Create a copy of SearchQuery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchQueryCopyWith<SearchQuery> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchQueryCopyWith<$Res> {
  factory $SearchQueryCopyWith(
          SearchQuery value, $Res Function(SearchQuery) then) =
      _$SearchQueryCopyWithImpl<$Res, SearchQuery>;
  @useResult
  $Res call(
      {String queryText,
      bool isExactMatch,
      Set<String> editionIds,
      bool searchInPali,
      bool searchInSinhala,
      Set<SearchScope> scope,
      int limit,
      int offset});
}

/// @nodoc
class _$SearchQueryCopyWithImpl<$Res, $Val extends SearchQuery>
    implements $SearchQueryCopyWith<$Res> {
  _$SearchQueryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchQuery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? isExactMatch = null,
    Object? editionIds = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? scope = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_value.copyWith(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      editionIds: null == editionIds
          ? _value.editionIds
          : editionIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      searchInPali: null == searchInPali
          ? _value.searchInPali
          : searchInPali // ignore: cast_nullable_to_non_nullable
              as bool,
      searchInSinhala: null == searchInSinhala
          ? _value.searchInSinhala
          : searchInSinhala // ignore: cast_nullable_to_non_nullable
              as bool,
      scope: null == scope
          ? _value.scope
          : scope // ignore: cast_nullable_to_non_nullable
              as Set<SearchScope>,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _value.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchQueryImplCopyWith<$Res>
    implements $SearchQueryCopyWith<$Res> {
  factory _$$SearchQueryImplCopyWith(
          _$SearchQueryImpl value, $Res Function(_$SearchQueryImpl) then) =
      __$$SearchQueryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String queryText,
      bool isExactMatch,
      Set<String> editionIds,
      bool searchInPali,
      bool searchInSinhala,
      Set<SearchScope> scope,
      int limit,
      int offset});
}

/// @nodoc
class __$$SearchQueryImplCopyWithImpl<$Res>
    extends _$SearchQueryCopyWithImpl<$Res, _$SearchQueryImpl>
    implements _$$SearchQueryImplCopyWith<$Res> {
  __$$SearchQueryImplCopyWithImpl(
      _$SearchQueryImpl _value, $Res Function(_$SearchQueryImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchQuery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? isExactMatch = null,
    Object? editionIds = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? scope = null,
    Object? limit = null,
    Object? offset = null,
  }) {
    return _then(_$SearchQueryImpl(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      editionIds: null == editionIds
          ? _value._editionIds
          : editionIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      searchInPali: null == searchInPali
          ? _value.searchInPali
          : searchInPali // ignore: cast_nullable_to_non_nullable
              as bool,
      searchInSinhala: null == searchInSinhala
          ? _value.searchInSinhala
          : searchInSinhala // ignore: cast_nullable_to_non_nullable
              as bool,
      scope: null == scope
          ? _value._scope
          : scope // ignore: cast_nullable_to_non_nullable
              as Set<SearchScope>,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      offset: null == offset
          ? _value.offset
          : offset // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$SearchQueryImpl implements _SearchQuery {
  const _$SearchQueryImpl(
      {required this.queryText,
      this.isExactMatch = false,
      final Set<String> editionIds = const {},
      this.searchInPali = true,
      this.searchInSinhala = true,
      final Set<SearchScope> scope = const {},
      this.limit = 50,
      this.offset = 0})
      : _editionIds = editionIds,
        _scope = scope;

  /// The search query text
  @override
  final String queryText;

  /// Whether to require exact word match (no prefix matching)
  /// Default false = prefix matching enabled (e.g., "සති" matches "සතිපට්ඨානය")
  @override
  @JsonKey()
  final bool isExactMatch;

  /// Editions to search within (e.g., {'bjt', 'sc'})
  /// If empty, searches all available editions
  final Set<String> _editionIds;

  /// Editions to search within (e.g., {'bjt', 'sc'})
  /// If empty, searches all available editions
  @override
  @JsonKey()
  Set<String> get editionIds {
    if (_editionIds is EqualUnmodifiableSetView) return _editionIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_editionIds);
  }

  /// Whether to search in Pali text
  @override
  @JsonKey()
  final bool searchInPali;

  /// Whether to search in Sinhala text
  @override
  @JsonKey()
  final bool searchInSinhala;

  /// Selected scope to search within.
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Example:
  /// - {} = search everything
  /// - {sutta} = search only Sutta Pitaka
  /// - {sutta, commentaries} = search Sutta Pitaka OR Commentaries
  final Set<SearchScope> _scope;

  /// Selected scope to search within.
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Example:
  /// - {} = search everything
  /// - {sutta} = search only Sutta Pitaka
  /// - {sutta, commentaries} = search Sutta Pitaka OR Commentaries
  @override
  @JsonKey()
  Set<SearchScope> get scope {
    if (_scope is EqualUnmodifiableSetView) return _scope;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_scope);
  }

  /// Maximum number of results to return
  @override
  @JsonKey()
  final int limit;

  /// Offset for pagination
  @override
  @JsonKey()
  final int offset;

  @override
  String toString() {
    return 'SearchQuery(queryText: $queryText, isExactMatch: $isExactMatch, editionIds: $editionIds, searchInPali: $searchInPali, searchInSinhala: $searchInSinhala, scope: $scope, limit: $limit, offset: $offset)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchQueryImpl &&
            (identical(other.queryText, queryText) ||
                other.queryText == queryText) &&
            (identical(other.isExactMatch, isExactMatch) ||
                other.isExactMatch == isExactMatch) &&
            const DeepCollectionEquality()
                .equals(other._editionIds, _editionIds) &&
            (identical(other.searchInPali, searchInPali) ||
                other.searchInPali == searchInPali) &&
            (identical(other.searchInSinhala, searchInSinhala) ||
                other.searchInSinhala == searchInSinhala) &&
            const DeepCollectionEquality().equals(other._scope, _scope) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      queryText,
      isExactMatch,
      const DeepCollectionEquality().hash(_editionIds),
      searchInPali,
      searchInSinhala,
      const DeepCollectionEquality().hash(_scope),
      limit,
      offset);

  /// Create a copy of SearchQuery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchQueryImplCopyWith<_$SearchQueryImpl> get copyWith =>
      __$$SearchQueryImplCopyWithImpl<_$SearchQueryImpl>(this, _$identity);
}

abstract class _SearchQuery implements SearchQuery {
  const factory _SearchQuery(
      {required final String queryText,
      final bool isExactMatch,
      final Set<String> editionIds,
      final bool searchInPali,
      final bool searchInSinhala,
      final Set<SearchScope> scope,
      final int limit,
      final int offset}) = _$SearchQueryImpl;

  /// The search query text
  @override
  String get queryText;

  /// Whether to require exact word match (no prefix matching)
  /// Default false = prefix matching enabled (e.g., "සති" matches "සතිපට්ඨානය")
  @override
  bool get isExactMatch;

  /// Editions to search within (e.g., {'bjt', 'sc'})
  /// If empty, searches all available editions
  @override
  Set<String> get editionIds;

  /// Whether to search in Pali text
  @override
  bool get searchInPali;

  /// Whether to search in Sinhala text
  @override
  bool get searchInSinhala;

  /// Selected scope to search within.
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Example:
  /// - {} = search everything
  /// - {sutta} = search only Sutta Pitaka
  /// - {sutta, commentaries} = search Sutta Pitaka OR Commentaries
  @override
  Set<SearchScope> get scope;

  /// Maximum number of results to return
  @override
  int get limit;

  /// Offset for pagination
  @override
  int get offset;

  /// Create a copy of SearchQuery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchQueryImplCopyWith<_$SearchQueryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
