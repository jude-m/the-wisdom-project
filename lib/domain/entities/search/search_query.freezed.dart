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

  /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Examples:
  /// - {} = search everything
  /// - {'sp'} = search only Sutta Pitaka
  /// - {'dn', 'mn'} = search Digha Nikaya OR Majjhima Nikaya
  /// - {'atta-vp', 'atta-sp', 'atta-ap'} = search all Commentaries
  Set<String> get scope => throw _privateConstructorUsedError;

  /// Whether to search as a phrase (consecutive words) or separate words.
  /// - true (DEFAULT) = phrase search (words must be adjacent)
  /// - false = separate-word search (words within proximity distance)
  bool get isPhraseSearch => throw _privateConstructorUsedError;

  /// Whether to ignore proximity and search anywhere in the same text unit.
  /// Only applies when [isPhraseSearch] is false.
  /// - true = search for words anywhere in the text (uses very large proximity)
  /// - false (DEFAULT) = use [proximityDistance] for proximity constraint
  bool get isAnywhereInText => throw _privateConstructorUsedError;

  /// Proximity distance for multi-word separate-word queries.
  /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
  /// Default 10 = words within 10 tokens (NEAR/10).
  /// Range: 1-100.
  int get proximityDistance => throw _privateConstructorUsedError;

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
      Set<String> scope,
      bool isPhraseSearch,
      bool isAnywhereInText,
      int proximityDistance,
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
    Object? isPhraseSearch = null,
    Object? isAnywhereInText = null,
    Object? proximityDistance = null,
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
              as Set<String>,
      isPhraseSearch: null == isPhraseSearch
          ? _value.isPhraseSearch
          : isPhraseSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      isAnywhereInText: null == isAnywhereInText
          ? _value.isAnywhereInText
          : isAnywhereInText // ignore: cast_nullable_to_non_nullable
              as bool,
      proximityDistance: null == proximityDistance
          ? _value.proximityDistance
          : proximityDistance // ignore: cast_nullable_to_non_nullable
              as int,
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
      Set<String> scope,
      bool isPhraseSearch,
      bool isAnywhereInText,
      int proximityDistance,
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
    Object? isPhraseSearch = null,
    Object? isAnywhereInText = null,
    Object? proximityDistance = null,
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
              as Set<String>,
      isPhraseSearch: null == isPhraseSearch
          ? _value.isPhraseSearch
          : isPhraseSearch // ignore: cast_nullable_to_non_nullable
              as bool,
      isAnywhereInText: null == isAnywhereInText
          ? _value.isAnywhereInText
          : isAnywhereInText // ignore: cast_nullable_to_non_nullable
              as bool,
      proximityDistance: null == proximityDistance
          ? _value.proximityDistance
          : proximityDistance // ignore: cast_nullable_to_non_nullable
              as int,
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
      final Set<String> scope = const {},
      this.isPhraseSearch = true,
      this.isAnywhereInText = false,
      this.proximityDistance = 10,
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

  /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Examples:
  /// - {} = search everything
  /// - {'sp'} = search only Sutta Pitaka
  /// - {'dn', 'mn'} = search Digha Nikaya OR Majjhima Nikaya
  /// - {'atta-vp', 'atta-sp', 'atta-ap'} = search all Commentaries
  final Set<String> _scope;

  /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Examples:
  /// - {} = search everything
  /// - {'sp'} = search only Sutta Pitaka
  /// - {'dn', 'mn'} = search Digha Nikaya OR Majjhima Nikaya
  /// - {'atta-vp', 'atta-sp', 'atta-ap'} = search all Commentaries
  @override
  @JsonKey()
  Set<String> get scope {
    if (_scope is EqualUnmodifiableSetView) return _scope;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_scope);
  }

  /// Whether to search as a phrase (consecutive words) or separate words.
  /// - true (DEFAULT) = phrase search (words must be adjacent)
  /// - false = separate-word search (words within proximity distance)
  @override
  @JsonKey()
  final bool isPhraseSearch;

  /// Whether to ignore proximity and search anywhere in the same text unit.
  /// Only applies when [isPhraseSearch] is false.
  /// - true = search for words anywhere in the text (uses very large proximity)
  /// - false (DEFAULT) = use [proximityDistance] for proximity constraint
  @override
  @JsonKey()
  final bool isAnywhereInText;

  /// Proximity distance for multi-word separate-word queries.
  /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
  /// Default 10 = words within 10 tokens (NEAR/10).
  /// Range: 1-100.
  @override
  @JsonKey()
  final int proximityDistance;

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
    return 'SearchQuery(queryText: $queryText, isExactMatch: $isExactMatch, editionIds: $editionIds, searchInPali: $searchInPali, searchInSinhala: $searchInSinhala, scope: $scope, isPhraseSearch: $isPhraseSearch, isAnywhereInText: $isAnywhereInText, proximityDistance: $proximityDistance, limit: $limit, offset: $offset)';
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
            (identical(other.isPhraseSearch, isPhraseSearch) ||
                other.isPhraseSearch == isPhraseSearch) &&
            (identical(other.isAnywhereInText, isAnywhereInText) ||
                other.isAnywhereInText == isAnywhereInText) &&
            (identical(other.proximityDistance, proximityDistance) ||
                other.proximityDistance == proximityDistance) &&
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
      isPhraseSearch,
      isAnywhereInText,
      proximityDistance,
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
      final Set<String> scope,
      final bool isPhraseSearch,
      final bool isAnywhereInText,
      final int proximityDistance,
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

  /// Search scope using tree node keys (e.g., 'sp', 'dn', 'kn-dhp').
  ///
  /// Empty set = search all content (no scope filter applied).
  /// Non-empty = search only within the selected scope (OR logic).
  ///
  /// Examples:
  /// - {} = search everything
  /// - {'sp'} = search only Sutta Pitaka
  /// - {'dn', 'mn'} = search Digha Nikaya OR Majjhima Nikaya
  /// - {'atta-vp', 'atta-sp', 'atta-ap'} = search all Commentaries
  @override
  Set<String> get scope;

  /// Whether to search as a phrase (consecutive words) or separate words.
  /// - true (DEFAULT) = phrase search (words must be adjacent)
  /// - false = separate-word search (words within proximity distance)
  @override
  bool get isPhraseSearch;

  /// Whether to ignore proximity and search anywhere in the same text unit.
  /// Only applies when [isPhraseSearch] is false.
  /// - true = search for words anywhere in the text (uses very large proximity)
  /// - false (DEFAULT) = use [proximityDistance] for proximity constraint
  @override
  bool get isAnywhereInText;

  /// Proximity distance for multi-word separate-word queries.
  /// Only applies when [isPhraseSearch] is false and [isAnywhereInText] is false.
  /// Default 10 = words within 10 tokens (NEAR/10).
  /// Range: 1-100.
  @override
  int get proximityDistance;

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
